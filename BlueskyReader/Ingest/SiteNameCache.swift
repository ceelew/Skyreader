import Foundation

/// UserDefaults-backed host → publication name cache, plus a set of hosts we've
/// already attempted a site-name fetch for (successful or not). Once a host has been
/// tried, we don't spend another page fetch on it just to learn its publication name.
final class SiteNameCache {
    static let shared = SiteNameCache()

    private let defaults: UserDefaults
    private let siteNamesKey = "SiteNameCache.siteNames"
    private let triedHostsKey = "SiteNameCache.triedHosts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func siteName(forHost host: String) -> String? {
        siteNames[host]
    }

    func hasTried(host: String) -> Bool {
        triedHosts.contains(host)
    }

    /// Records a successful og:site_name lookup and marks the host tried.
    func record(siteName: String, forHost host: String) {
        var names = siteNames
        names[host] = siteName
        siteNames = names
        markTried(host: host)
    }

    /// Marks a host as attempted even when no site name was found, so we don't
    /// keep re-fetching hosts that simply don't provide og:site_name.
    func markTried(host: String) {
        guard !triedHosts.contains(host) else { return }
        triedHosts.insert(host)
    }

    private var siteNames: [String: String] {
        get { (defaults.dictionary(forKey: siteNamesKey) as? [String: String]) ?? [:] }
        set { defaults.set(newValue, forKey: siteNamesKey) }
    }

    private var triedHosts: Set<String> {
        get { Set(defaults.stringArray(forKey: triedHostsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: triedHostsKey) }
    }
}
