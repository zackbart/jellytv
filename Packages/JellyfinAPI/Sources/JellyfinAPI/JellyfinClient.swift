import Foundation

@available(tvOS 15.0, macOS 12.0, *)
public actor JellyfinClient: JellyfinClientAPI {

    // MARK: - State

    private var serverURL: URL?
    private var accessToken: String?

    // MARK: - Immutable configuration

    private let deviceId: String
    private let clientName: String
    private let clientVersion: String
    private let deviceName: String

    // MARK: - Networking

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Init

    public init(
        deviceId: String,
        clientName: String = "JellyTV",
        clientVersion: String = "1.0",
        deviceName: String = "Apple TV",
        session: URLSession? = nil
    ) {
        self.deviceId = deviceId
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.deviceName = deviceName

        if let session {
            self.session = session
        } else {
            self.session = URLSession(configuration: .ephemeral)
        }

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        self.encoder = JSONEncoder()
    }

    // MARK: - Protocol: State setters

    public func setServerURL(_ url: URL?) async {
        serverURL = url
    }

    public func setAccessToken(_ token: String?) async {
        accessToken = token
    }

    // MARK: - Protocol: Endpoints

    public func getPublicSystemInfo() async throws -> PublicSystemInfo {
        let request = try buildRequest(path: "/System/Info/Public")
        return try await send(request, as: PublicSystemInfo.self)
    }

    public func authenticateByName(username: String, password: String) async throws -> AuthenticationResult {
        let body = try encoder.encode(AuthenticationRequest(username: username, pw: password))
        let request = try buildRequest(path: "/Users/AuthenticateByName", method: "POST", body: body)
        return try await send(request, as: AuthenticationResult.self)
    }

    public func quickConnectEnabled() async throws -> Bool {
        let request = try buildRequest(path: "/QuickConnect/Enabled")
        return try await send(request, as: Bool.self)
    }

    public func quickConnectInitiate() async throws -> QuickConnectResult {
        let request = try buildRequest(path: "/QuickConnect/Initiate", method: "POST")
        do {
            return try await send(request, as: QuickConnectResult.self)
        } catch JellyfinError.unauthenticated {
            throw JellyfinError.quickConnectDisabled
        }
    }

    public func quickConnectStatus(secret: String) async throws -> QuickConnectResult {
        let request = try buildRequest(
            path: "/QuickConnect/Connect",
            queryItems: [URLQueryItem(name: "secret", value: secret)]
        )
        do {
            return try await send(request, as: QuickConnectResult.self)
        } catch JellyfinError.http(status: 404, _) {
            throw JellyfinError.quickConnectExpired
        }
    }

    public func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult {
        let body = try encoder.encode(QuickConnectAuthRequest(secret: secret))
        let request = try buildRequest(path: "/Users/AuthenticateWithQuickConnect", method: "POST", body: body)
        return try await send(request, as: AuthenticationResult.self)
    }

    public func currentUser() async throws -> UserDto {
        let request = try buildRequest(path: "/Users/Me")
        return try await send(request, as: UserDto.self)
    }

    public func logout() async throws {
        let request = try buildRequest(path: "/Sessions/Logout", method: "POST")
        try await sendIgnoringResponse(request)
    }

    // MARK: - Private: Authorization header

    private func authorizationHeaderValue() -> String {
        var parts = [
            "Client=\"\(percentEncode(clientName))\"",
            "Device=\"\(percentEncode(deviceName))\"",
            "DeviceId=\"\(percentEncode(deviceId))\"",
            "Version=\"\(percentEncode(clientVersion))\"",
        ]
        if let token = accessToken {
            parts.append("Token=\"\(percentEncode(token))\"")
        }
        return "MediaBrowser " + parts.joined(separator: ", ")
    }

    private func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    // MARK: - Private: Request builder

    private func buildRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let serverURL else { throw JellyfinError.notConfigured }
        var components = URLComponents(
            url: serverURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw JellyfinError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authorizationHeaderValue(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    // MARK: - Private: Send helpers

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type = T.self) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw JellyfinError.network(urlError)
        } catch {
            throw JellyfinError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                throw JellyfinError.decoding(decodingError)
            }
        case 401:
            throw JellyfinError.unauthenticated
        default:
            let problem = try? decoder.decode(ProblemDetails.self, from: data)
            throw JellyfinError.http(status: http.statusCode, problem: problem)
        }
    }

    private func sendIgnoringResponse(_ request: URLRequest) async throws {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw JellyfinError.network(urlError)
        } catch {
            throw JellyfinError.network(URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.network(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw JellyfinError.unauthenticated
        default:
            let problem = try? decoder.decode(ProblemDetails.self, from: data)
            throw JellyfinError.http(status: http.statusCode, problem: problem)
        }
    }
}
