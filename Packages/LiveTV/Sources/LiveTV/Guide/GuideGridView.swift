import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

/// The actual EPG grid: sticky channel column + horizontally-scrolling time
/// grid + a sticky "focused program" detail strip at the bottom that shows
/// the title, time, and overview of whatever cell currently has focus.
struct GuideGridView: View {
    let content: GuideContent
    let onWatchChannel: (LiveTvChannel) -> Void
    let onSelectProgram: (LiveTvProgram) -> Void

    @FocusedValue(\.focusedGuideProgram) private var focusedProgram
    @FocusedValue(\.focusedGuideChannel) private var focusedChannel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    channelColumn
                    programArea
                }
            }
            .scrollClipDisabled()

            FocusedProgramFooter(
                program: focusedProgram,
                channel: focusedChannel,
                serverURL: content.serverURL
            )
        }
    }

    // MARK: - Channel column

    private var channelColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: GuideLayout.timeHeaderHeight)
            ForEach(content.channels) { channel in
                ChannelRowHeader(
                    channel: channel,
                    serverURL: content.serverURL,
                    onTap: { onWatchChannel(channel) }
                )
                .frame(height: GuideLayout.rowHeight)
            }
        }
        .frame(width: GuideLayout.channelColumnWidth)
        .focusSection()
    }

    // MARK: - Program area

    private var programArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TimeHeader(windowStart: content.windowStart, windowEnd: content.windowEnd)
                    .frame(height: GuideLayout.timeHeaderHeight)
                ForEach(content.channels) { channel in
                    GuideChannelLane(
                        channel: channel,
                        programs: content.programs(for: channel.id),
                        windowStart: content.windowStart,
                        windowEnd: content.windowEnd,
                        onSelectProgram: onSelectProgram
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                nowLine(windowStart: content.windowStart)
            }
        }
        .scrollClipDisabled()
    }

    /// Vertical "now" indicator. Wrapped in `TimelineView` so the line position
    /// updates once per minute. Critical: only the line itself is inside the
    /// timeline closure — the program grid is a sibling, so timeline ticks
    /// don't rebuild program cells (which would drop tvOS focus).
    private func nowLine(windowStart: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let secondsSinceStart = context.date.timeIntervalSince(windowStart)
            let x = GuideLayout.offset(forSecondsSinceWindowStart: secondsSinceStart)
            VStack(spacing: 0) {
                Color.clear.frame(height: GuideLayout.timeHeaderHeight)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                    .shadow(color: .red.opacity(0.6), radius: 8, x: 0, y: 0)
            }
            .offset(x: x)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Channel row header (left column)

private struct ChannelRowHeader: View {
    let channel: LiveTvChannel
    let serverURL: URL
    let onTap: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                    .frame(width: 64, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    if let number = channel.number, !number.isEmpty {
                        Text(number)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(channel.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(isFocused ? .primary : .secondary)
                }
                Spacer(minLength: 0)
                if channel.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedGuideChannel, isFocused ? channel : nil)
    }
}

// MARK: - Time header

private struct TimeHeader: View {
    let windowStart: Date
    let windowEnd: Date

    var body: some View {
        let slots = halfHourSlots(from: windowStart, to: windowEnd)
        ZStack(alignment: .topLeading) {
            ForEach(slots, id: \.self) { slot in
                let offset = GuideLayout.offset(
                    forSecondsSinceWindowStart: slot.timeIntervalSince(windowStart)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(LiveTvFormat.timeFormatter.string(from: slot))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 1, height: 8)
                }
                .offset(x: offset, y: 16)
            }
        }
        .frame(width: totalWidth, alignment: .topLeading)
    }

    private var totalWidth: CGFloat {
        let minutes = windowEnd.timeIntervalSince(windowStart) / 60.0
        return CGFloat(minutes) * GuideLayout.pixelsPerMinute
    }

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

// MARK: - Single channel lane (row of program cells)

private struct GuideChannelLane: View {
    let channel: LiveTvChannel
    let programs: [LiveTvProgram]
    let windowStart: Date
    let windowEnd: Date
    let onSelectProgram: (LiveTvProgram) -> Void

    var body: some View {
        LazyHStack(alignment: .top, spacing: 0) {
            if programs.isEmpty {
                emptyLane
            } else {
                ForEach(programs) { program in
                    cell(for: program)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: GuideLayout.rowHeight, alignment: .topLeading)
        .focusSection()
    }

    @ViewBuilder
    private func cell(for program: LiveTvProgram) -> some View {
        if let start = program.startDate, let end = program.endDate, end > start {
            let visibleStart = max(start, windowStart)
            let duration = end.timeIntervalSince(visibleStart)
            let cellWidth = GuideLayout.width(forDuration: duration)
            FocusableProgramCell(
                program: program,
                width: cellWidth,
                onSelect: { onSelectProgram(program) }
            )
        } else {
            FocusableProgramCell(
                program: program,
                width: GuideLayout.minimumProgramCellWidth,
                onSelect: { onSelectProgram(program) }
            )
        }
    }

    private var emptyLane: some View {
        Text("No information")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(width: laneWidth, height: GuideLayout.rowHeight, alignment: .leading)
            .background(.white.opacity(0.04))
    }

    private var laneWidth: CGFloat {
        let minutes = windowEnd.timeIntervalSince(windowStart) / 60.0
        return CGFloat(minutes) * GuideLayout.pixelsPerMinute
    }
}

// MARK: - Program cell (focusable)

private struct FocusableProgramCell: View {
    let program: LiveTvProgram
    let width: CGFloat
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onSelect) {
            content
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedGuideProgram, isFocused ? program : nil)
    }

    private var content: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let isAiringNow: Bool = {
                guard let start = program.startDate, let end = program.endDate else { return false }
                return now >= start && now < end
            }()
            let progress = LiveTvFormat.progressFraction(start: program.startDate, end: program.endDate, now: now)

            ZStack(alignment: .topLeading) {
                background(isAiringNow: isAiringNow)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if isAiringNow {
                            LiveBadge(label: "LIVE")
                        }
                        if program.isPremiere == true {
                            tag("PREMIERE", color: .pink)
                        } else if program.isRepeat == true {
                            tag("REPEAT", color: .gray)
                        }
                    }
                    Text(program.name)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundStyle(isFocused ? .primary : .primary.opacity(0.9))
                    if let timeRange = LiveTvFormat.timeRange(start: program.startDate, end: program.endDate) {
                        Text(timeRange)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)

                if isAiringNow, let progress {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: geo.size.width * progress, height: 3)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
        }
        .frame(width: width, height: GuideLayout.rowHeight, alignment: .topLeading)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func background(isAiringNow: Bool) -> some View {
        let baseColor: Color = isAiringNow
            ? Color.accentColor.opacity(isFocused ? 0.55 : 0.30)
            : Color.white.opacity(isFocused ? 0.18 : 0.08)
        RoundedRectangle(cornerRadius: 8)
            .fill(baseColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? .white.opacity(0.6) : .white.opacity(0.10), lineWidth: 1)
            )
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
    }
}

// MARK: - Focused-program footer

private struct FocusedProgramFooter: View {
    let program: LiveTvProgram?
    let channel: LiveTvChannel?
    let serverURL: URL

    var body: some View {
        Group {
            if let program {
                HStack(alignment: .top, spacing: 16) {
                    if let channel {
                        ChannelLogoView(channel: channel, serverURL: serverURL, maxWidth: 240)
                            .frame(width: 80, height: 56)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(program.name)
                                .font(.title3.weight(.semibold))
                                .lineLimit(1)
                            if let year = program.productionYear {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let rating = program.officialRating {
                                Text(rating)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if let episodeTitle = program.episodeTitle {
                            Text(episodeTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let overview = program.overview {
                            Text(overview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: program?.id)
    }
}

// MARK: - Filter pill bar

struct CategoryFilterBar: View {
    let selected: GuideCategory
    let onSelect: (GuideCategory) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(GuideCategory.allCases) { category in
                FilterPill(
                    title: category.title,
                    icon: category.icon,
                    isSelected: category == selected
                ) {
                    onSelect(category)
                }
            }
        }
        .focusSection()
    }
}

private struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(background, in: Capsule())
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
    }

    private var background: Color {
        if isSelected { return .accentColor.opacity(0.7) }
        if isFocused { return .white.opacity(0.18) }
        return .white.opacity(0.08)
    }
}

// MARK: - Focus values

struct FocusedGuideProgramKey: FocusedValueKey {
    typealias Value = LiveTvProgram
}

struct FocusedGuideChannelKey: FocusedValueKey {
    typealias Value = LiveTvChannel
}

extension FocusedValues {
    var focusedGuideProgram: LiveTvProgram? {
        get { self[FocusedGuideProgramKey.self] }
        set { self[FocusedGuideProgramKey.self] = newValue }
    }
    var focusedGuideChannel: LiveTvChannel? {
        get { self[FocusedGuideChannelKey.self] }
        set { self[FocusedGuideChannelKey.self] = newValue }
    }
}
