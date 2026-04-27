import SwiftUI
import JellyfinAPI

/// Presents `LiveTVPlayerView` full-screen on tvOS (as a `fullScreenCover`)
/// and as a sheet on macOS so the LiveTV package compiles cleanly for both
/// platforms. Centralized here so any view that surfaces channels can wire
/// the same playback path simply by binding `selectedChannel`.
public struct ChannelPlayerPresentation: ViewModifier {
    @Binding var selectedChannel: LiveTvChannel?
    let openStream: @Sendable (LiveTvChannel) async throws -> URL

    public init(
        selectedChannel: Binding<LiveTvChannel?>,
        openStream: @escaping @Sendable (LiveTvChannel) async throws -> URL
    ) {
        self._selectedChannel = selectedChannel
        self.openStream = openStream
    }

    public func body(content: Content) -> some View {
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
