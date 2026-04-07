import SwiftUI
import JellyfinAPI

#if os(tvOS)
import AVKit
import UIKit
#endif

/// Resolves a live stream URL for a channel, then plays it via
/// `AVPlayerViewController` on tvOS. On macOS this view shows a "tvOS only"
/// fallback so the LiveTV package compiles for both platforms.
public struct LiveTVPlayerView: View {
    public let channel: LiveTvChannel
    public let openStream: @Sendable (LiveTvChannel) async throws -> URL
    public let onDismiss: () -> Void

    @State private var streamURL: URL?
    @State private var errorMessage: String?

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
        Group {
            if let errorMessage {
                failedView(message: errorMessage)
            } else if let streamURL {
                #if os(tvOS)
                LiveTvAVPlayerControllerRepresentable(url: streamURL)
                    .ignoresSafeArea()
                #else
                macOSStub
                #endif
            } else {
                ProgressView("Opening \(channel.name)\u{2026}")
                    .controlSize(.large)
            }
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

    @MainActor
    final class Coordinator {
        var player: AVPlayer?
        var statusObservation: NSKeyValueObservation?
        var failedObserver: NSObjectProtocol?
        // Cleanup happens in `dismantleUIViewController`. We deliberately do
        // NOT implement `deinit` here — `deinit` is `nonisolated` by default
        // under Swift 6 strict concurrency and would not be allowed to touch
        // these `@MainActor`-isolated stored properties.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        JellytvLog.player.info("AVPlayerViewController: makeUIViewController url=\(url.absoluteString, privacy: .public)")
        let controller = AVPlayerViewController()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        controller.player = player
        context.coordinator.player = player

        // Log status changes — .failed surfaces the actual AVFoundation error.
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

        // Catches mid-playback failures (network drop, server kick, etc.).
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
}
#endif
