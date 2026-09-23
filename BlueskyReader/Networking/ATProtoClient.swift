import Foundation

/// Owns the Bluesky session (tokens) and serializes refresh so concurrent
/// requests don't double-refresh. Knows nothing about the database.
actor ATProtoClient {
    private let baseURL = URL(string: "https://bsky.social/xrpc/")!
    private let session: URLSession

    private(set) var accessJwt: String?
    private(set) var refreshJwt: String?
    private(set) var did: String?
    private(set) var handle: String?

    /// In-flight refresh task, so concurrent 401s share one refresh instead of racing.
    private var refreshTask: Task<Void, Error>?

    init(session: URLSession = .shared) {
        self.session = session
        self.accessJwt = KeychainStore.get(KeychainStore.Key.accessJwt.rawValue)
        self.refreshJwt = KeychainStore.get(KeychainStore.Key.refreshJwt.rawValue)
        self.did = KeychainStore.get(KeychainStore.Key.did.rawValue)
        self.handle = KeychainStore.get(KeychainStore.Key.handle.rawValue)
    }

    var isAuthenticated: Bool { accessJwt != nil && did != nil }

    // MARK: - Auth

    func login(handle: String, appPassword: String) async throws {
        let url = baseURL.appendingPathComponent("com.atproto.server.createSession")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["identifier": handle, "password": appPassword])

        let (data, response) = try await performRaw(request)
        try Self.checkStatus(response, data: data)

        let decoded: CreateSessionResponse
        do {
            decoded = try JSONDecoder().decode(CreateSessionResponse.self, from: data)
        } catch {
            throw ATProtoError.decoding(error)
        }

        persistSession(
            accessJwt: decoded.accessJwt,
            refreshJwt: decoded.refreshJwt,
            did: decoded.did,
            handle: decoded.handle
        )
        KeychainStore.set(appPassword, for: KeychainStore.Key.appPassword.rawValue)
    }

    func logout() {
        accessJwt = nil
        refreshJwt = nil
        did = nil
        handle = nil
        KeychainStore.deleteAll()
    }

    /// Performs an authenticated GET against the given XRPC method, refreshing the
    /// session and retrying once if the access token has expired.
    func authenticatedGet(method: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(method), resolvingAgainstBaseURL: false) else {
            throw ATProtoError.network(URLError(.badURL))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw ATProtoError.network(URLError(.badURL)) }

        return try await performAuthenticated(url: url, retrying: true)
    }

    private func performAuthenticated(url: URL, retrying: Bool) async throws -> Data {
        guard let accessJwt else { throw ATProtoError.notAuthenticated }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRaw(request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let errorBody = try? JSONDecoder().decode(ATProtoErrorBody.self, from: data)
            let decision = Self.classifyStatus(
                status: http.statusCode,
                errorBody: errorBody,
                allowExpiredRetry: retrying,
                rateLimitResetHeader: http.value(forHTTPHeaderField: "ratelimit-reset"),
                now: Date()
            )
            switch decision {
            case .ok:
                break
            case .retryExpiredToken:
                try await refreshSession()
                return try await performAuthenticated(url: url, retrying: false)
            case .invalidCredentials:
                throw ATProtoError.invalidCredentials
            case .rateLimited(let retryAfter):
                throw ATProtoError.rateLimited(retryAfter: retryAfter)
            case .server(let status, let message):
                throw ATProtoError.server(status: status, message: message)
            }
        }
        return data
    }

    /// Serializes concurrent refresh attempts behind a single shared task.
    private func refreshSession() async throws {
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task { () throws -> Void in
            try await self.doRefresh()
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    private func doRefresh() async throws {
        guard let refreshJwt else {
            try await reLoginWithStoredPassword()
            return
        }

        let url = baseURL.appendingPathComponent("com.atproto.server.refreshSession")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(refreshJwt)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await performRaw(request)
            try Self.checkStatus(response, data: data)
            let decoded = try JSONDecoder().decode(RefreshSessionResponse.self, from: data)
            persistSession(
                accessJwt: decoded.accessJwt,
                refreshJwt: decoded.refreshJwt,
                did: decoded.did,
                handle: decoded.handle
            )
        } catch {
            try await reLoginWithStoredPassword()
        }
    }

    private func reLoginWithStoredPassword() async throws {
        guard let handle = handle ?? KeychainStore.get(KeychainStore.Key.handle.rawValue),
              let appPassword = KeychainStore.get(KeychainStore.Key.appPassword.rawValue) else {
            logout()
            throw ATProtoError.notAuthenticated
        }
        try await login(handle: handle, appPassword: appPassword)
    }

    private func persistSession(accessJwt: String, refreshJwt: String, did: String, handle: String) {
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
        self.did = did
        self.handle = handle

        KeychainStore.set(accessJwt, for: KeychainStore.Key.accessJwt.rawValue)
        KeychainStore.set(refreshJwt, for: KeychainStore.Key.refreshJwt.rawValue)
        KeychainStore.set(did, for: KeychainStore.Key.did.rawValue)
        KeychainStore.set(handle, for: KeychainStore.Key.handle.rawValue)
    }

    private func performRaw(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ATProtoError.network(error)
        }
    }

    private static func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard !(200..<300).contains(http.statusCode) else { return }

        let errorBody = try? JSONDecoder().decode(ATProtoErrorBody.self, from: data)
        let decision = classifyStatus(
            status: http.statusCode,
            errorBody: errorBody,
            allowExpiredRetry: false,
            rateLimitResetHeader: http.value(forHTTPHeaderField: "ratelimit-reset"),
            now: Date()
        )
        switch decision {
        case .ok, .retryExpiredToken:
            // Non-2xx never maps to these when allowExpiredRetry is false.
            return
        case .invalidCredentials:
            throw ATProtoError.invalidCredentials
        case .rateLimited(let retryAfter):
            throw ATProtoError.rateLimited(retryAfter: retryAfter)
        case .server(let status, let message):
            throw ATProtoError.server(status: status, message: message)
        }
    }

    /// Pure status → error classification, factored out so it's unit-testable without the network.
    enum StatusDecision: Equatable {
        case ok
        case retryExpiredToken
        case invalidCredentials
        case rateLimited(retryAfter: TimeInterval?)
        case server(status: Int, message: String?)
    }

    static func classifyStatus(
        status: Int,
        errorBody: ATProtoErrorBody?,
        allowExpiredRetry: Bool,
        rateLimitResetHeader: String?,
        now: Date
    ) -> StatusDecision {
        if (200..<300).contains(status) {
            return .ok
        }
        if status == 429 {
            return .rateLimited(retryAfter: retryAfterInterval(fromEpochHeader: rateLimitResetHeader, now: now))
        }
        if status == 401 {
            return .invalidCredentials
        }
        if status == 400 {
            switch errorBody?.error {
            case "ExpiredToken":
                return allowExpiredRetry ? .retryExpiredToken : .invalidCredentials
            case "InvalidToken", "AuthenticationRequired":
                return .invalidCredentials
            default:
                return .server(status: 400, message: errorBody?.message ?? errorBody?.error)
            }
        }
        return .server(status: status, message: errorBody?.message ?? errorBody?.error)
    }

    /// `ratelimit-reset` is a UNIX epoch-seconds timestamp, not a delta — convert to
    /// seconds-from-now and clamp to non-negative.
    static func retryAfterInterval(fromEpochHeader header: String?, now: Date) -> TimeInterval? {
        guard let header, let epochSeconds = TimeInterval(header) else { return nil }
        return max(0, epochSeconds - now.timeIntervalSince1970)
    }

    // MARK: - Timeline

    func getTimeline(limit: Int = 100, cursor: String? = nil) async throws -> GetTimelineResponse {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let data = try await authenticatedGet(method: "app.bsky.feed.getTimeline", queryItems: items)
        do {
            return try JSONDecoder().decode(GetTimelineResponse.self, from: data)
        } catch {
            throw ATProtoError.decoding(error)
        }
    }
}
