import SwiftUI
import JellyfinAPI

struct ProgramCell: View {
    let program: LiveTvProgram
    let width: CGFloat
    let isAiringNow: Bool
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onSelect) {
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
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($isFocused)
        .focusedValue(\.focusedProgram, isFocused ? program : nil)
    }

    private var timeRange: String? {
        guard let start = program.startDate, let end = program.endDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

// MARK: - FocusedValue plumbing

private struct FocusedProgramKey: FocusedValueKey {
    typealias Value = LiveTvProgram
}

extension FocusedValues {
    var focusedProgram: LiveTvProgram? {
        get { self[FocusedProgramKey.self] }
        set { self[FocusedProgramKey.self] = newValue }
    }
}
