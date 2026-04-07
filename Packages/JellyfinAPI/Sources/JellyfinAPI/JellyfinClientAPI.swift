import Foundation

public protocol JellyfinClientAPI: Sendable {
    /// Set or change the server URL. Pass nil to clear.
    func setServerURL(_ url: URL?) async

    /// Get the current server URL, if configured.
    func currentServerURL() async -> URL?

    /// Set or clear the access token used by authenticated calls.
    func setAccessToken(_ token: String?) async

    // MARK: - Auth

    func getPublicSystemInfo() async throws -> PublicSystemInfo
    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult

    func quickConnectEnabled() async throws -> Bool
    func quickConnectInitiate() async throws -> QuickConnectResult
    func quickConnectStatus(secret: String) async throws -> QuickConnectResult
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult

    func currentUser() async throws -> UserDto
    func logout() async throws

    // MARK: - Home

    /// GET /UserViews — returns libraries (collections like Movies, TV Shows, etc.)
    func userViews() async throws -> [BaseItemDto]

    /// GET /UserItems/Resume?limit=... — Continue Watching
    func resumeItems(limit: Int) async throws -> [BaseItemDto]

    /// GET /Shows/NextUp?limit=... — Next Up episodes
    func nextUp(limit: Int) async throws -> [BaseItemDto]

    /// GET /Items/Latest?parentId=...&limit=... — Latest items per library
    func latestItems(parentId: String?, limit: Int) async throws -> [BaseItemDto]
}
