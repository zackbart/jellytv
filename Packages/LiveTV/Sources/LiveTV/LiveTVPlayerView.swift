import SwiftUI
import NukeUI
import JellyfinAPI
import DesignSystem

#if os(tvOS)
import AVKit
import UIKit
#endif

/// Resolves a live stream URL for a channel, then plays it via
/// `AVPlayerViewController` on tvOS. Inject channel + currently-airing
/// program metadata into `AVPlayerItem.externalMetadata` so the tvOS
/// info panel (press-up on the Siri Remote) shows title, channel, and
/// overview. On macOS this view shows a "tvOS only" fallback so the
/// LiveTV package compiles for both platforms.
public struct LiveTVPlayerView: View {
    public let channel: LiveTvChannel
    public let openStream: @Sendable (LiveTvChannel) async throws -> URL
    public let onDismiss: () -> Void

    @State private var streamURL: URL?
    @State private var errorMessage: String?
    @State private var serverURL: URL?

    public init(
        channel: LiveTvChannel,
        openStream: @escaping @Sendable (LiveTvChannel) async throws -> URL,
        onDismiss: @escaping () -> Void
    ) {
        self.channel = channel
        self.openStream = openStream
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
        }
        .task(id: channel.id) {
            JellytvLog.player.info("LiveTVPlayerView: opening stream for channel \(channel.id, privacy: .public) (\(channel.name, privacy: .public))")
            errorMessage = nil
            streamURL = nil
            do {
                let url = try await openStream(channel)
                JellytvLog.player.info("LiveTVPlayerView: stream URL ready: \(url.absoluteString, privacy: .public)")
                streamURL = url
            } catch {
                JellytvLog.player.error("LiveTVPlayerView: openStream failed for channel \(channel.id, privacy: .public): \(String(describing: error), privacy: .public)")
                errorMessage = "Couldn't start playback: \(error.localizedDescription)"
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            failedView(message: errorMessage)
        } else if let streamURL {
            #if os(tvOS)
            LiveTvAVPlayerControllerRepresentable(
                url: streamURL,
                channel: channel,
                program: channel.currentProgram
            )
            .ignoresSafeArea()
            #else
            macOSStub
            #endif
        } else {
            loadingState
        }
    }

    private var loadingState: some View {
        VStack(spacing: 28) {
            VStack(spacing: 18) {
                channelArtwork
                    .frame(width: 160, height: 90)
                VStack(spacing: 4) {
                    Text(channel.name)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    if let number = channel.number, !number.isEmpty {
                        Text("Channel \(number)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ProgressView()
                .controlSize(.large)
            Text("Tuning in…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var channelArtwork: some View {
        if let logoURL = channelLogoURL {
            LazyImage(url: logoURL) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var channelLogoURL: URL? {
        guard let serverURL else { return nil }
        return channel.logoURL(serverURL: serverURL, maxWidth: 480)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Image(systemName: "tv")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
            HStack(spacing: 24) {
                Button("Retry") {
                    Task {
                        errorMessage = nil
                        streamURL = nil
                        do {
                            streamURL = try await openStream(channel)
                        } catch {
                            errorMessage = "Couldn't start playback: \(error.localizedDescription)"
                        }
                    }
                }
                Button("Dismiss") {
                    onDismiss()
                }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if !os(tvOS)
    private var macOSStub: some View {
        VStack(spacing: 16) {
            Text("Live TV playback is tvOS only.")
                .font(.title2)
            Button("Dismiss") { onDismiss() }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    #endif
}

#if os(tvOS)
private struct LiveTvAVPlayerControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    let channel: LiveTvChannel
    let program: LiveTvProgram?

    @MainActor
    final class Coordinator {
        var player: AVPlayer?
        var statusObservation: NSKeyValueObservation?
        var failedObserver: NSObjectProtocol?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        JellytvLog.player.info("AVPlayerViewController: makeUIViewController url=\(url.absoluteString, privacy: .public)")
        let controller = AVPlayerViewController()
        controller.appliesPreferredDisplayCriteriaAutomatically = true

        let item = AVPlayerItem(url: url)
        item.externalMetadata = LiveTvAVPlayerControllerRepresentable.makeExternalMetadata(
            channel: channel,
            program: program
        )
        let player = AVPlayer(playerItem: item)
        controller.player = player
        context.coordinator.player = player

        context.coordinator.statusObservation = item.observe(\.status, options: [.new]) { item, _ in
            switch item.status {
            case .readyToPlay:
                JellytvLog.player.info("AVPlayerItem status: readyToPlay")
            case .failed:
                if let err = item.error {
                    JellytvLog.player.error("AVPlayerItem status: failed — \(String(describing: err), privacy: .public)")
                } else {
                    JellytvLog.player.error("AVPlayerItem status: failed (no error)")
                }
            case .unknown:
                JellytvLog.player.debug("AVPlayerItem status: unknown")
            @unknown default:
                JellytvLog.player.debug("AVPlayerItem status: @unknown")
            }
        }

        context.coordinator.failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            JellytvLog.player.error("AVPlayerItem failedToPlayToEndTime: \(String(describing: err), privacy: .public)")
        }

        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player?.rate == 0 {
            controller.player?.play()
        }
    }

    static func dismantleUIViewController(
        _ controller: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        JellytvLog.player.info("AVPlayerViewController: dismantle")
        coordinator.statusObservation?.invalidate()
        coordinator.statusObservation = nil
        if let failedObserver = coordinator.failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            coordinator.failedObserver = nil
        }
        coordinator.player?.pause()
        coordinator.player = nil
        controller.player = nil
    }

    /// Builds `AVPlayerItem.externalMetadata` so the tvOS press-up info panel
    /// shows program title / channel / overview / genre — the same affordance
    /// Plex Live TV provides via the OSD. We deliberately push as much detail
    /// here as Jellyfin returns: AVKit lays it out for free.
    static func makeExternalMetadata(
        channel: LiveTvChannel,
        program: LiveTvProgram?
    ) -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []

        let title = program?.name ?? channel.name
        items.append(metadata(identifier: .commonIdentifierTitle, value: title))

        var subtitleParts: [String] = []
        if let number = channel.number, !number.isEmpty {
            subtitleParts.append("CH \(number)")
        }
        subtitleParts.append(channel.name)
        if let episodeTitle = program?.episodeTitle, !episodeTitle.isEmpty {
            subtitleParts.append(episodeTitle)
        }
        items.append(metadata(
            identifier: .iTunesMetadataTrackSubTitle,
            value: subtitleParts.joined(separator: " · ")
        ))

        if let overview = program?.overview, !overview.isEmpty {
            items.append(metadata(identifier: .commonIdentifierDescription, value: overview))
        }
        if let genres = program?.genres, !genres.isEmpty {
            items.append(metadata(identifier: .quickTimeMetadataGenre, value: genres.joined(separator: ", ")))
        }
        if let year = program?.productionYear {
            items.append(metadata(identifier: .commonIdentifierCreationDate, value: String(year)))
        }
        return items
    }

    private static func metadata(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }
}
#endif
