import Foundation

public protocol JellyfinClientAPI: Sendable {
    /// Set or change the server URL. Pass nil to clear.
    func setServerURL(_ url: URL?) async

    /// Set or clear the access token used by authenticated calls.
    func setAccessToken(_ token: String?) async

    func getPublicSystemInfo() async throws -> PublicSystemInfo
    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult

    func quickConnectEnabled() async throws -> Bool
    func quickConnectInitiate() async throws -> QuickConnectResult
    func quickConnectStatus(secret: String) async throws -> QuickConnectResult
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult

    func currentUser() async throws -> UserDto
    func logout() async throws
}
