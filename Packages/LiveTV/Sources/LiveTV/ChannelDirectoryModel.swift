import Foundation
import Observation
import JellyfinAPI

/// Canonical, filter-independent list of all live TV channels for the current
/// session, sorted by channel number. Lives at the `LiveTVRootView` level so
/// the player can drive channel up/down regardless of which tab loaded which
/// per-tab channel slice. Refreshed on appear, every 5 minutes thereafter,
/// and on demand when a tune fails (channel possibly removed server-side).
@MainActor
@Observable
public final class ChannelDirectoryModel {
    public private(set) var channels: [LiveTvChannel] = []
    public private(set) var isLoading: Bool = false
    public private(set) var lastError: String?

    private let client: any JellyfinClientAPI

    public init(client: any JellyfinClientAPI) {
        self.client = client
    }

    /// Fetch the full channel list and sort it. Idempotent — safe to call
    /// repeatedly. Concurrent refresh calls are coalesced via `isLoading`.
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        JellytvLog.liveTV.info("ChannelDirectoryModel.refresh: begin")
        do {
            let raw = try await client.liveTvChannels()
            channels = ChannelOrdering.sortedByChannelNumber(raw)
            lastError = nil
            JellytvLog.liveTV.info("ChannelDirectoryModel.refresh: \(self.channels.count) channels")
        } catch {
            lastError = String(describing: error)
            JellytvLog.liveTV.error("ChannelDirectoryModel.refresh: \(String(describing: error), privacy: .public)")
        }
    }
}
