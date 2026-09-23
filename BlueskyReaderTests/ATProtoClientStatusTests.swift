import XCTest
@testable import BlueskyReader

final class ATProtoClientStatusTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testSuccessStatusIsOK() {
        let decision = ATProtoClient.classifyStatus(
            status: 200, errorBody: nil, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .ok)
    }

    func test401IsInvalidCredentials() {
        let decision = ATProtoClient.classifyStatus(
            status: 401, errorBody: nil, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .invalidCredentials)
    }

    func test400ExpiredTokenRetriesWhenAllowed() {
        let body = ATProtoErrorBody(error: "ExpiredToken", message: nil)
        let decision = ATProtoClient.classifyStatus(
            status: 400, errorBody: body, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .retryExpiredToken)
    }

    func test400ExpiredTokenIsInvalidCredentialsWhenRetryExhausted() {
        let body = ATProtoErrorBody(error: "ExpiredToken", message: nil)
        let decision = ATProtoClient.classifyStatus(
            status: 400, errorBody: body, allowExpiredRetry: false, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .invalidCredentials)
    }

    func test400InvalidTokenIsInvalidCredentials() {
        let body = ATProtoErrorBody(error: "InvalidToken", message: nil)
        let decision = ATProtoClient.classifyStatus(
            status: 400, errorBody: body, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .invalidCredentials)
    }

    func test400AuthenticationRequiredIsInvalidCredentials() {
        let body = ATProtoErrorBody(error: "AuthenticationRequired", message: nil)
        let decision = ATProtoClient.classifyStatus(
            status: 400, errorBody: body, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .invalidCredentials)
    }

    func testOther400IsServerError() {
        let body = ATProtoErrorBody(error: "SomethingElse", message: "nope")
        let decision = ATProtoClient.classifyStatus(
            status: 400, errorBody: body, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .server(status: 400, message: "nope"))
    }

    func test429ParsesRateLimitResetAsEpochDelta() {
        let resetEpoch = now.timeIntervalSince1970 + 30
        let decision = ATProtoClient.classifyStatus(
            status: 429, errorBody: nil, allowExpiredRetry: true,
            rateLimitResetHeader: String(Int(resetEpoch)), now: now
        )
        guard case .rateLimited(let retryAfter) = decision else {
            return XCTFail("expected rateLimited, got \(decision)")
        }
        XCTAssertEqual(retryAfter ?? -1, 30, accuracy: 1)
    }

    func test429ClampsPastResetToZero() {
        let resetEpoch = now.timeIntervalSince1970 - 30
        let decision = ATProtoClient.classifyStatus(
            status: 429, errorBody: nil, allowExpiredRetry: true,
            rateLimitResetHeader: String(Int(resetEpoch)), now: now
        )
        XCTAssertEqual(decision, .rateLimited(retryAfter: 0))
    }

    func testOtherStatusIsServerError() {
        let decision = ATProtoClient.classifyStatus(
            status: 503, errorBody: nil, allowExpiredRetry: true, rateLimitResetHeader: nil, now: now
        )
        XCTAssertEqual(decision, .server(status: 503, message: nil))
    }
}
