import Foundation
import JellyfinAPI

public enum JellyfinImage {
    public static func url(
        serverURL: URL,
        itemId: String,
        type: ImageType,
        tag: String?,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil
    ) -> URL? {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemId)/Images/\(type.rawValue)"),
            resolvingAgainstBaseURL: false
        )

        var queryItems: [URLQueryItem] = []
        if let tag = tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if let maxWidth = maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: String(maxWidth)))
        }
        if let maxHeight = maxHeight {
            queryItems.append(URLQueryItem(name: "maxHeight", value: String(maxHeight)))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        return components?.url
    }

    public enum ImageType: String, Sendable {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case art = "Art"
    }
}

public extension BaseItemDto {
    func imageURL(
        serverURL: URL,
        type: JellyfinImage.ImageType,
        maxWidth: Int? = nil
    ) -> URL? {
        let tag: String?
        switch type {
        case .primary:
            tag = imageTags?["Primary"]
        case .backdrop:
            tag = backdropImageTags?.first
        case .thumb, .logo, .art:
            tag = nil
        }
        guard let tag = tag else { return nil }
        return JellyfinImage.url(
            serverURL: serverURL,
            itemId: id,
            type: type,
            tag: tag,
            maxWidth: maxWidth
        )
    }
}