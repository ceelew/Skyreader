//  Bundle+AppVersion.swift
//  Reads the app's version/build straight from Info.plist so display strings
//  never drift from what's actually shipped.

import Foundation

extension Bundle {
    /// "1.0 (1)"-style version string built from CFBundleShortVersionString and
    /// CFBundleVersion. Falls back to "—" if either is missing.
    var appVersionString: String {
        guard
            let shortVersion = infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = infoDictionary?["CFBundleVersion"] as? String
        else { return "—" }
        return "\(shortVersion) (\(build))"
    }
}
