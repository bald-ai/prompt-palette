import Foundation

/// A list of child indexes that points to an item inside the prompt tree.
/// For example, `[0, 2, 1]` means: first root item -> third child -> second child.
typealias ItemPath = [Int]

struct PromptItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String?
    var children: [PromptItem]?
    let createdAt: Date
    var updatedAt: Date
    var useCount: Int

    init(
        id: UUID,
        title: String,
        content: String?,
        children: [PromptItem]?,
        createdAt: Date,
        updatedAt: Date,
        useCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.children = children
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useCount = useCount
    }

    var isFolder: Bool {
        children != nil
    }

    var isPrompt: Bool {
        children == nil && content != nil
    }

    var descendantCount: Int {
        guard let children else {
            return 0
        }

        return children.reduce(children.count) { partialResult, child in
            partialResult + child.descendantCount
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case children
        case createdAt
        case updatedAt
        case useCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        children = try container.decodeIfPresent([PromptItem].self, forKey: .children)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
    }
}
