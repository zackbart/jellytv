import SwiftUI
import JellyfinAPI

/// Top-level Live TV experience. Wraps three tabs (On Now / Guide /
/// Recordings) in a `TabView` so users can navigate the way they would in
/// Plex or YouTube TV. Each tab owns its own `@Observable` model that pulls
/// from the shared `JellyfinClientAPI` actor.
///
/// The per-tab models are held as `@State` so they survive `body`
/// re-evaluations across tab changes — recreating them inline would discard
/// loaded content every render.
public struct LiveTVRootView: View {
    public let client: any JellyfinClientAPI

    @State private var onNowModel: OnNowModel
    @State private var guideModel: GuideModel
    @State private var recordingsModel: RecordingsModel
    @State private var channelDirectory: ChannelDirectoryModel
    @State private var selectedChannel: LiveTvChannel?
    @State private var selectedProgram: LiveTvProgram?
    @State private var lastWatchedChannelId: String?
    @State private var serverURL: URL?

    public init(client: any JellyfinClientAPI) {
        self.client = client
        _onNowModel = State(initialValue: OnNowModel(client: client))
        _guideModel = State(initialValue: GuideModel(client: client))
        _recordingsModel = State(initialValue: RecordingsModel(client: client))
        _channelDirectory = State(initialValue: ChannelDirectoryModel(client: client))
    }

    public var body: some View {
        TabView {
            OnNowView(
                model: onNowModel,
                onWatchChannel: { selectedChannel = $0 },
                onSelectProgram: { selectedProgram = $0 }
            )
            .tabItem {
                Label("On Now", systemImage: "dot.radiowaves.left.and.right")
            }

            GuideView(
                model: guideModel,
                onWatchChannel: { selectedChannel = $0 },
                onSelectProgram: { selectedProgram = $0 },
                lastWatchedChannelId: $lastWatchedChannelId
            )
            .tabItem {
                Label("Guide", systemImage: "tv.and.hifispeaker.fill")
            }

            RecordingsView(model: recordingsModel)
                .tabItem {
                    Label("Recordings", systemImage: "record.circle")
                }
        }
        .task {
            // Resolve server URL once for the player + log the channel-directory
            // refresh. Both children read these.
            serverURL = await client.currentServerURL()
            await channelDirectory.refresh()
        }
        .modifier(LiveTVPresentations(
            selectedChannel: $selectedChannel,
            selectedProgram: $selectedProgram,
            channels: channelDirectory.channels,
            serverURL: serverURL,
            lastWatchedChannelId: $lastWatchedChannelId,
            client: client
        ))
    }
}

/// Centralized full-screen / sheet presentation so each tab doesn't need to
/// own player + program-detail navigation independently.
private struct LiveTVPresentations: ViewModifier {
    @Binding var selectedChannel: LiveTvChannel?
    @Binding var selectedProgram: LiveTvProgram?
    let channels: [LiveTvChannel]
    let serverURL: URL?
    @Binding var lastWatchedChannelId: String?
    let client: any JellyfinClientAPI

    func body(content: Content) -> some View {
        content
            .modifier(ChannelPlayerPresentation(
                selectedChannel: $selectedChannel,
                channels: channels,
                serverURL: serverURL ?? URL(string: "about:blank")!,
                program: nil,
                openStream: { [client] channel, force in
                    try await client.liveTvOpenStream(channelId: channel.id, forceTranscoding: force)
                },
                closeStream: { [client] id in
                    try? await client.liveTvCloseStream(liveStreamId: id)
                },
                lastWatchedChannelId: $lastWatchedChannelId
            ))
            .modifier(ProgramDetailPresentation(
                selectedProgram: $selectedProgram,
                client: client,
                onWatchChannel: { channel in
                    selectedProgram = nil
                    selectedChannel = channel
                }
            ))
    }
}
