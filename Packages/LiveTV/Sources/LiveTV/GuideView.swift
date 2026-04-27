import SwiftUI
import JellyfinAPI
import DesignSystem

/// Plex-style EPG guide. Channels run as rows; the time grid runs as a
/// horizontally-scrolling lane on the right. Programs are focusable so users
/// can drill into a `ProgramDetailView` from the guide. A category-filter
/// pill bar at the top scopes the channel list (All / Favorites / Movies /
/// Sports / News / Kids).
///
/// Selection is callback-driven so this view can be embedded inside the
/// `LiveTVRootView` tab shell, which centralizes player + detail
/// presentation.
public struct GuideView: View {
    @Bindable var model: GuideModel
    let onWatchChannel: (LiveTvChannel) -> Void
    let onSelectProgram: (LiveTvProgram) -> Void
    @Binding var lastWatchedChannelId: String?

    public init(
        model: GuideModel,
        onWatchChannel: @escaping (LiveTvChannel) -> Void = { _ in },
        onSelectProgram: @escaping (LiveTvProgram) -> Void = { _ in },
        lastWatchedChannelId: Binding<String?> = .constant(nil)
    ) {
        self.model = model
        self.onWatchChannel = onWatchChannel
        self.onSelectProgram = onSelectProgram
        self._lastWatchedChannelId = lastWatchedChannelId
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CategoryFilterBar(
                selected: model.categoryFilter,
                onSelect: { filter in
                    Task { await model.applyFilter(filter) }
                }
            )
            .padding(.horizontal, 60)
            .padding(.top, 30)
            .padding(.bottom, 16)

            content
        }
        .task {
            if case .loading = model.state {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            loadingState
        case .loaded(let snapshot):
            if snapshot.isEmpty {
                emptyState
            } else {
                GuideGridView(
                    content: snapshot,
                    onWatchChannel: onWatchChannel,
                    onSelectProgram: onSelectProgram,
                    lastWatchedChannelId: $lastWatchedChannelId
                )
            }
        case .failed(let message):
            failedView(message)
        }
    }

    private var loadingState: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("No channels match this filter")
                .font(.title)
            Text("Try a different category, or check that your Jellyfin server has Live TV configured.")
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
