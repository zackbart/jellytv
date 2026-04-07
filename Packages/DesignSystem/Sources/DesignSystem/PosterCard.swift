import SwiftUI
import Nuke
import NukeUI
import JellyfinAPI

public struct PosterCard<Item: Identifiable & Sendable>: View {
    let item: Item
    let title: String
    let imageURL: URL?
    public let action: () -> Void

    public init(
        item: Item,
        title: String,
        imageURL: URL?,
        action: @escaping () -> Void
    ) {
        self.item = item
        self.title = title
        self.imageURL = imageURL
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let url = imageURL {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else if state.error != nil {
                                placeholderView
                            } else {
                                placeholderView
                            }
                        }
                        .aspectRatio(2/3, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholderView
                            .aspectRatio(2/3, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .containerRelativeFrame(.horizontal, count: 6, spacing: 0)
                .opacity(0.9)

                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.borderless)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}