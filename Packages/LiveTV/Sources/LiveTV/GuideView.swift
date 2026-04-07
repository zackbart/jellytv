import SwiftUI
import JellyfinAPI

public struct GuideView: View {
    @Bindable var model: GuideModel
    @State var selectedChannel: LiveTvChannel?

    public init(model: GuideModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case .loaded(let content):
                if content.isEmpty {
                    emptyState
                } else {
                    grid(content: content)
                }
            case .failed(let message):
                failedView(message)
            }
        }
        .task {
            await model.load()
        }
        .modifier(ChannelPlayerPresentation(
            selectedChannel: $selectedChannel,
            openStream: { [model] ch in
                try await model.openStream(channelId: ch.id).playbackURL
            }
        ))
    }

    // MARK: - Grid

    @ViewBuilder
    private func grid(content: GuideContent) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                channelColumn(content: content)
                programArea(content: content)
            }
        }
    }

    private func channelColumn(content: GuideContent) -> some View {
        VStack(spacing: 0) {
            // Spacer matching the time header height so channel rows line up
            // with their corresponding program rows.
            Color.clear.frame(height: GuideLayout.timeHeaderHeight)
            ForEach(content.channels) { channel in
                ChannelLabel(channel: channel) { selected in
                    selectedChannel = selected
                }
                .frame(height: GuideLayout.rowHeight)
            }
        }
        .frame(width: GuideLayout.channelColumnWidth)
    }

    private func programArea(content: GuideContent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TimeHeader(windowStart: content.windowStart, windowEnd: content.windowEnd)
                    .frame(height: GuideLayout.timeHeaderHeight)
                ForEach(content.channels) { channel in
                    ChannelRow(
                        channel: channel,
                        programs: content.programs(for: channel.id),
                        windowStart: content.windowStart,
                        now: content.windowStart
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                nowLineOverlay(windowStart: content.windowStart)
            }
        }
    }

    /// Vertical "now" indicator. Wrapped in `TimelineView` so the line position
    /// updates once per minute. Critical: only the line itself is inside the
    /// timeline closure — the program grid is a sibling, so timeline ticks
    /// don't rebuild program cells (which would drop tvOS focus).
    private func nowLineOverlay(windowStart: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let secondsSinceStart = context.date.timeIntervalSince(windowStart)
            let x = GuideLayout.offset(forSecondsSinceWindowStart: secondsSinceStart)
            VStack(spacing: 0) {
                Color.clear.frame(height: GuideLayout.timeHeaderHeight)
                Rectangle()
                    .fill(.red)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
            .offset(x: x)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Empty / Failed

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("No channels")
                .font(.title)
            Text("Your Jellyfin server isn't reporting any Live TV channels.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reload") {
                Task { await model.load() }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await model.load() }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Channel player presentation

/// Wraps the player presentation in a platform-aware modifier so the LiveTV
/// package compiles for both tvOS (full-screen cover) and macOS (sheet).
private struct ChannelPlayerPresentation: ViewModifier {
    @Binding var selectedChannel: LiveTvChannel?
    let openStream: @Sendable (LiveTvChannel) async throws -> URL

    func body(content: Content) -> some View {
        #if os(tvOS)
        content.fullScreenCover(item: $selectedChannel) { channel in
            LiveTVPlayerView(
                channel: channel,
                openStream: openStream,
                onDismiss: { selectedChannel = nil }
            )
        }
        #else
        content.sheet(item: $selectedChannel) { channel in
            LiveTVPlayerView(
                channel: channel,
                openStream: openStream,
                onDismiss: { selectedChannel = nil }
            )
        }
        #endif
    }
}

// MARK: - Channel label

private struct ChannelLabel: View {
    let channel: LiveTvChannel
    let onSelect: (LiveTvChannel) -> Void

    var body: some View {
        Button {
            onSelect(channel)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let number = channel.number, !number.isEmpty {
                    Text(number)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(channel.name)
                    .font(.headline)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }
}

// MARK: - Time header

private struct TimeHeader: View {
    let windowStart: Date
    let windowEnd: Date

    var body: some View {
        let slots = halfHourSlots(from: windowStart, to: windowEnd)
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.timeStyle = .short
            f.dateStyle = .none
            return f
        }()
        ZStack(alignment: .topLeading) {
            ForEach(slots, id: \.self) { slot in
                let offset = GuideLayout.offset(
                    forSecondsSinceWindowStart: slot.timeIntervalSince(windowStart)
                )
                Text(formatter.string(from: slot))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .offset(x: offset, y: 16)
            }
        }
        .frame(width: totalWidth, alignment: .topLeading)
    }

    private var totalWidth: CGFloat {
        let minutes = windowEnd.timeIntervalSince(windowStart) / 60.0
        return CGFloat(minutes) * GuideLayout.pixelsPerMinute
    }

    /// 30-minute boundaries strictly inside `[start, end]`. The first slot is
    /// the next 30-min boundary at or after `start`.
    private func halfHourSlots(from start: Date, to end: Date) -> [Date] {
        var slots: [Date] = []
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        var rounded = calendar.date(from: comps) ?? start
        if let minute = comps.minute, minute > 0 && minute < 30 {
            rounded = rounded.addingTimeInterval(TimeInterval((30 - minute) * 60))
        } else if let minute = comps.minute, minute > 30 {
            rounded = rounded.addingTimeInterval(TimeInterval((60 - minute) * 60))
        }
        var slot = rounded
        while slot < end {
            slots.append(slot)
            slot = slot.addingTimeInterval(30 * 60)
        }
        return slots
    }
}
