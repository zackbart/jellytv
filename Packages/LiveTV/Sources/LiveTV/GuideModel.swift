import Foundation
import Observation
import JellyfinAPI

@MainActor
@Observable
public final class GuideModel {
    public enum State: Equatable, Sendable {
        case loading
        case loaded(GuideContent)
        case failed(String)
    }

    public private(set) var state: State = .loading

    private let client: any JellyfinClientAPI
    private let now: @Sendable () -> Date

    public init(
        client: any JellyfinClientAPI,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.now = now
    }

    public func load() async {
        JellytvLog.liveTV.info("GuideModel.load() begin")
        state = .loading

        guard let serverURL = await client.currentServerURL() else {
            JellytvLog.liveTV.error("GuideModel.load: not signed in (no serverURL)")
            state = .failed("Not signed in")
            return
        }

        let windowStart = now()
        let windowEnd = windowStart.addingTimeInterval(GuideLayout.futureWindowSeconds)
        let fetchStart = windowStart.addingTimeInterval(-GuideLayout.pastWindowSeconds)

        do {
            let channels = try await client.liveTvChannels()
            let validChannelIds = Set(channels.map(\.id))
            let programs: [LiveTvProgram]
            if channels.isEmpty {
                programs = []
            } else {
                programs = try await client.liveTvPrograms(
                    channelIds: channels.map(\.id),
                    minStartDate: fetchStart,
                    maxStartDate: windowEnd
                )
            }

            // Group programs by channel, dropping any whose channelId isn't in
            // the channel list (defensive — server shouldn't return them) and
            // any whose endDate is at or before the visible window start
            // (program already finished). Programs missing dates are kept under
            // their channel — the view will skip them.
            var grouped: [String: [LiveTvProgram]] = [:]
            for program in programs {
                guard let channelId = program.channelId,
                      validChannelIds.contains(channelId) else { continue }
                if let endDate = program.endDate, endDate <= windowStart { continue }
                grouped[channelId, default: []].append(program)
            }
            // Sort each channel's programs by startDate ascending.
            for (channelId, list) in grouped {
                grouped[channelId] = list.sorted { lhs, rhs in
                    (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
                }
            }

            let content = GuideContent(
                serverURL: serverURL,
                windowStart: windowStart,
                windowEnd: windowEnd,
                channels: channels,
                programsByChannel: grouped
            )
            JellytvLog.liveTV.info("GuideModel.load: loaded \(channels.count) channels, \(programs.count) programs")
            state = .loaded(content)
        } catch JellyfinError.network {
            JellytvLog.liveTV.error("GuideModel.load: network failure")
            state = .failed("Couldn't reach the server.")
        } catch JellyfinError.unauthenticated {
            JellytvLog.liveTV.error("GuideModel.load: unauthenticated")
            state = .failed("Session expired. Please sign in again.")
        } catch {
            JellytvLog.liveTV.error("GuideModel.load: \(String(describing: error), privacy: .public)")
            state = .failed("Something went wrong: \(error)")
        }
    }

    /// Resolves the live playback URL for a channel. Delegates to the
    /// underlying client so that token + URL construction stay encapsulated.
    public func openStream(channelId: String) async throws -> LiveStreamPlayback {
        try await client.liveTvOpenStream(channelId: channelId)
    }
}
