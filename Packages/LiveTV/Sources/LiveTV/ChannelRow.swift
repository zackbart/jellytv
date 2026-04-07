import SwiftUI
import JellyfinAPI

struct ChannelRow: View {
    let channel: LiveTvChannel
    let programs: [LiveTvProgram]
    let windowStart: Date
    let now: Date

    var body: some View {
        LazyHStack(alignment: .top, spacing: 0) {
            ForEach(programs) { program in
                programOrGap(for: program)
            }
            // Trailing filler so the row's intrinsic width matches the grid width
            // even when the last program ends before the window does.
            Spacer(minLength: 0)
        }
        .frame(height: GuideLayout.rowHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func programOrGap(for program: LiveTvProgram) -> some View {
        if let start = program.startDate, let end = program.endDate, end > start {
            let visibleStart = max(start, windowStart)
            let duration = end.timeIntervalSince(visibleStart)
            let cellWidth = GuideLayout.width(forDuration: duration)
            let isAiringNow = now >= start && now < end
            ProgramCell(
                program: program,
                width: cellWidth,
                isAiringNow: isAiringNow
            )
        } else {
            ProgramCell(
                program: program,
                width: GuideLayout.minimumProgramCellWidth,
                isAiringNow: false
            )
        }
    }
}
