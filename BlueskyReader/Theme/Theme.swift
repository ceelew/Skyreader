//  Theme.swift
//  Skyreader design system — colours, spacing, type.
//  Every colour resolves from Assets/Colors (light + dark appearances),
//  every font is a Dynamic Type text style. Nothing here reads a hex at runtime.

import SwiftUI

extension Color {
    static let paper         = Color("Paper")         // FBFAF7 / 131211
    static let surface       = Color("Surface")       // FFFFFF / 1B1917
    static let rule          = Color("Rule")          // E4E0D9 / 302D29
    static let ink           = Color("Ink")           // 1C1A17 / EDEAE4
    static let inkSecondary  = Color("InkSecondary")  // 55504A / ADA69C
    static let inkTertiary   = Color("InkTertiary")   // 787169 / 8A847B
    static let accent        = Color("Accent")        // 1185FE / 4DA2FF  — glyphs, dots, links
    static let accentStrong  = Color("AccentStrong")  // 0B62D6 / 4DA2FF  — filled buttons only
    static let destructive   = Color("Destructive")   // C8462F / E0705A
}

/// 4pt base scale. Use these, never a literal.
enum Space {
    static let xxs:  CGFloat = 2
    static let xs:   CGFloat = 4
    static let s:    CGFloat = 8
    static let m:    CGFloat = 12
    static let l:    CGFloat = 16
    static let xl:   CGFloat = 20   // the one horizontal margin, everywhere
    static let xxl:  CGFloat = 28   // above a day header
    static let xxxl: CGFloat = 40   // masthead to first section, form blocks
}

extension Font {
    /// New York, semibold — the masthead only.
    static let masthead    = Font.system(.largeTitle, design: .serif).weight(.semibold)
    /// New York, semibold — article headlines.
    static let articleHead = Font.system(.title3, design: .serif).weight(.semibold)
    /// New York, regular — a headline that hasn't resolved yet (shows the host).
    static let unresolved  = Font.system(.title3, design: .serif)
    /// New York, italic — the sharer's own words.
    static let commentary  = Font.system(.footnote, design: .serif).italic()
    /// SF — "Publication · shared by @handle · 2h ago".
    static let meta        = Font.subheadline
    /// SF, semibold, set uppercase + tracking 0.9 at the call site.
    static let dayHeader   = Font.footnote.weight(.semibold)
}

extension View {
    /// Standard row insets: 20 leading/trailing, 14 top, 16 bottom, min height 64.
    func skyreaderRowInsets() -> some View {
        self.padding(.horizontal, Space.xl)
            .padding(.top, 14)
            .padding(.bottom, Space.l)
            .frame(minHeight: 64, alignment: .top)
    }
}

extension Date {
    /// "2h ago", "1d ago" — short, lowercase, no "about".
    var relativeShort: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: .now)
    }
}
