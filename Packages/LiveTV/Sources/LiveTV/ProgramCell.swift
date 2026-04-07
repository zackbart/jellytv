import SwiftUI
import JellyfinAPI

/// Visual-only program rectangle. Not focusable — channel selection happens
/// at the ChannelLabel level (per UX choice in Phase C: only channels are
/// selectable, not programs).
struct ProgramCell: View {
    let program: LiveTvProgram
    let width: CGFloat
    let isAiringNow: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let timeRange {
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isAiringNow {
                Text("LIVE")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
            }
        }
        .padding(10)
        .frame(width: width, height: GuideLayout.rowHeight, alignment: .topLeading)
        .background(.regularMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var timeRange: String? {
        guard let start = program.startDate, let end = program.endDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
