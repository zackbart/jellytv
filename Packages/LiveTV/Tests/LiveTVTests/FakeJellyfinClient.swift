import Foundation
@testable import JellyfinAPI

/// Fake `JellyfinClientAPI` conformance for `GuideModel` tests. Mirrors the
/// `Result<…>`-stub pattern used by `Library/Tests/.../HomeModelTests.swift`.
final class FakeJellyfinClient: JellyfinClientAPI, @unchecked Sendable {
    var currentServerURL_: URL? = URL(string: "http://192.168.1.50:8096")

    var liveTvChannelsResult: Result<[LiveTvChannel], Error> = .success([])
    var liveTvProgramsResult: Result<[LiveTvProgram], Error> = .success([])
    var liveTvOpenStreamResult: Result<LiveStreamPlayback, Error> = .success(
        LiveStreamPlayback(playbackURL: URL(string: "http://test/stream")!, liveStreamId: nil)
    )

    /// Captured arguments to `liveTvPrograms` for assertions.
    private(set) var lastChannelIds: [String]?
    private(set) var lastMinStartDate: Date?
    private(set) var lastMaxStartDate: Date?
    private(set) var lastOpenStreamChannelId: String?

    func setServerURL(_ url: URL?) async { currentServerURL_ = url }
    func currentServerURL() async -> URL? { currentServerURL_ }
    func setAccessToken(_ token: String?) async {}

    func getPublicSystemInfo() async throws -> PublicSystemInfo {
        PublicSystemInfo(serverName: "Fake", version: "1.0", id: nil, productName: nil, localAddress: nil, startupWizardCompleted: nil)
    }

    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult {
        throw JellyfinError.unauthenticated
    }

    func quickConnectEnabled() async throws -> Bool { false }
    func quickConnectInitiate() async throws -> QuickConnectResult { throw JellyfinError.unauthenticated }
    func quickConnectStatus(secret: String) async throws -> QuickConnectResult { throw JellyfinError.unauthenticated }
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult { throw JellyfinError.unauthenticated }
    func currentUser() async throws -> UserDto { throw JellyfinError.unauthenticated }
    func logout() async throws {}

    func userViews() async throws -> [BaseItemDto] { [] }
    func resumeItems(limit: Int) async throws -> [BaseItemDto] { [] }
    func nextUp(limit: Int) async throws -> [BaseItemDto] { [] }
    func latestItems(parentId: String?, limit: Int) async throws -> [BaseItemDto] { [] }

    func liveTvChannels() async throws -> [LiveTvChannel] {
        try liveTvChannelsResult.get()
    }

    func liveTvPrograms(
        channelIds: [String],
        minStartDate: Date,
        maxStartDate: Date
    ) async throws -> [LiveTvProgram] {
        lastChannelIds = channelIds
        lastMinStartDate = minStartDate
        lastMaxStartDate = maxStartDate
        return try liveTvProgramsResult.get()
    }

    func liveTvOpenStream(channelId: String) async throws -> LiveStreamPlayback {
        lastOpenStreamChannelId = channelId
        return try liveTvOpenStreamResult.get()
    }
}
