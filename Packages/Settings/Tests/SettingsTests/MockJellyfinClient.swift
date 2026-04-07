import Foundation
@testable import JellyfinAPI

final class MockJellyfinClient: JellyfinClientAPI, @unchecked Sendable {
    // Stubs — set by tests before calling.
    var publicSystemInfoResult: Result<PublicSystemInfo, Error> = .success(
        PublicSystemInfo(serverName: "MockServer", version: "10.11.8", id: "mock", productName: nil, localAddress: nil, startupWizardCompleted: true)
    )
    var quickConnectInitiateResult: Result<QuickConnectResult, Error> = .success(
        QuickConnectResult(authenticated: false, secret: "mock-secret", code: "ABC123", deviceId: nil, deviceName: nil, appName: nil, appVersion: nil, dateAdded: nil)
    )
    var quickConnectStatusResults: [Result<QuickConnectResult, Error>] = []
    var authenticateByNameResult: Result<AuthenticationResult, Error> = .failure(JellyfinError.unauthenticated)
    var authenticateWithQuickConnectResult: Result<AuthenticationResult, Error> = .failure(JellyfinError.unauthenticated)

    var setServerURLCalls: [URL?] = []
    var setAccessTokenCalls: [String?] = []
    var quickConnectStatusCallCount: Int = 0

    func setServerURL(_ url: URL?) async {
        setServerURLCalls.append(url)
    }

    func setAccessToken(_ token: String?) async {
        setAccessTokenCalls.append(token)
    }

    func getPublicSystemInfo() async throws -> PublicSystemInfo {
        try publicSystemInfoResult.get()
    }

    func authenticateByName(username: String, password: String) async throws -> AuthenticationResult {
        try authenticateByNameResult.get()
    }

    func quickConnectEnabled() async throws -> Bool { true }

    func quickConnectInitiate() async throws -> QuickConnectResult {
        try quickConnectInitiateResult.get()
    }

    func quickConnectStatus(secret: String) async throws -> QuickConnectResult {
        quickConnectStatusCallCount += 1
        if !quickConnectStatusResults.isEmpty {
            return try quickConnectStatusResults.removeFirst().get()
        }
        return try quickConnectInitiateResult.get()
    }

    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult {
        try authenticateWithQuickConnectResult.get()
    }

    func currentUser() async throws -> UserDto {
        UserDto(id: "u1", name: "Mock User", serverId: nil, primaryImageTag: nil, hasPassword: true, hasConfiguredPassword: true, lastLoginDate: nil, lastActivityDate: nil)
    }

    func logout() async throws {}
}
