import SwiftUI

/// Typography ramp for the Live TV experience. Pairs SF Pro Rounded for display
/// headlines (the channel splash channel name, hero titles) with monospaced
/// digits for everything that needs to feel like a TV channel guide
/// (channel numbers, time labels). Body text stays on system SF.
public enum LiveTVTypography {
    /// Display-weight headline — for the channel splash channel name and
    /// other hero titles. Rounded variant gives the "fun TV" feel.
    public static let display: Font = .system(size: 64, weight: .heavy, design: .rounded)

    /// Strong title — section headers, error-card title.
    public static let strongTitle: Font = .title2.weight(.bold)

    /// Time labels in the EPG header and elapsed/remaining. Bigger and
    /// higher-contrast than the previous .subheadline-secondary treatment.
    public static let timeLabel: Font = .headline.monospacedDigit()

    /// Channel number ("101", "203") — always monospaced so the column of
    /// numbers in the guide visually aligns.
    public static let channelNumber: Font = .caption.monospacedDigit().weight(.semibold)

    /// Channel name in the guide channel column.
    public static let channelName: Font = .headline

    /// Program title in the splash and HUD.
    public static let programTitle: Font = .title3.weight(.semibold)

    /// Program time-range under the title.
    public static let programTime: Font = .subheadline.monospacedDigit()

    /// "LIVE" / "PREMIERE" / "REPEAT" tag pills.
    public static let tag: Font = .caption2.weight(.heavy)
}
