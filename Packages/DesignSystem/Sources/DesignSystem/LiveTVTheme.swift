import SwiftUI

/// Warm sports-broadcast palette for the Live TV experience. Deep navy-charcoal
/// background, broadcast-amber accent, broadcast-red live indicator. Plain
/// SwiftUI `Color` constants — no Asset Catalog indirection (tvOS-only single
/// theme, dark-mode-always).
public enum LiveTVTheme {
    /// Deepest background — full-bleed page background.
    public static let background = Color(red: 0.05, green: 0.07, blue: 0.12)

    /// Slightly lifted surface for cards / overlays. Combine with `background`
    /// underneath to suggest depth.
    public static let surface = Color.white.opacity(0.04)

    /// Focus and emphasis accent — warm broadcast amber. Use for focused
    /// borders, channel-cell glow, primary action buttons (Retry, etc.).
    public static let accent = Color(red: 1.00, green: 0.74, blue: 0.27)

    /// "On air" red — exclusively for the LIVE badge, the now-line, and other
    /// "this is happening right now" affordances. Don't use for general
    /// emphasis (that's `accent`).
    public static let live = Color(red: 1.00, green: 0.27, blue: 0.20)

    /// Body text. White on the dark background.
    public static let text = Color.white

    /// De-emphasized body text — captions, time-ranges, secondary metadata.
    public static let secondaryText = Color.white.opacity(0.65)

    /// Hairline divider between rows / sections.
    public static let divider = Color.white.opacity(0.08)
}
