import SwiftUI
import JellyfinAPI

public struct Shelf<Item: Identifiable & Sendable>: View {
    let title: String
    let items: [Item]
    let itemTitle: (Item) -> String
    let imageURL: (Item) -> URL?
    let onItemTap: (Item) -> Void

    public init(
        title: String,
        items: [Item],
        itemTitle: @escaping (Item) -> String,
        imageURL: @escaping (Item) -> URL?,
        onItemTap: @escaping (Item) -> Void
    ) {
        self.title = title
        self.items = items
        self.itemTitle = itemTitle
        self.imageURL = imageURL
        self.onItemTap = onItemTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, 40)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(items) { item in
                        PosterCard(
                            item: item,
                            title: itemTitle(item),
                            imageURL: imageURL(item)
                        ) {
                            onItemTap(item)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}