import Combine
import Foundation

enum PromptStoreError: LocalizedError, Equatable {
    case emptyTitle
    case emptyContent
    case itemNotFound
    case invalidFolder
    case invalidPromptState
    case maxDepthExceeded
    case childLimitExceeded
    case invalidMoveDestination

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty."
        case .emptyContent:
            return "Content cannot be empty."
        case .itemNotFound:
            return "The selected item could not be found."
        case .invalidFolder:
            return "That folder is no longer available."
        case .invalidPromptState:
            return "The prompt data is invalid."
        case .maxDepthExceeded:
            return "Folders can only be nested 5 levels deep."
        case .childLimitExceeded:
            return "Each level can contain up to 9 items."
        case .invalidMoveDestination:
            return "That move is not allowed."
        }
    }
}

@MainActor
final class PromptStore: ObservableObject {
    static let maxDepth = 5
    static let maxChildrenPerParent = 9

    @Published private(set) var prompts: [PromptItem] = []
    @Published private(set) var loadFailureMessage: String?

    let directoryURL: URL
    let promptsFileURL: URL

    init(directoryURL: URL = PromptStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
        self.promptsFileURL = directoryURL.appendingPathComponent("prompts.json")
    }

    nonisolated static func defaultDirectoryURL() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("PromptPalette", isDirectory: true)
    }

    func load() {
        guard FileManager.default.fileExists(atPath: promptsFileURL.path) else {
            prompts = []
            loadFailureMessage = nil
            return
        }

        do {
            let data = try Data(contentsOf: promptsFileURL)
            let decoded = try JSONDecoder.promptPaletteDecoder.decode([PromptItem].self, from: data)
            try validateTree(decoded)
            prompts = decoded
            loadFailureMessage = nil
        } catch {
            NSLog("PromptPalette: Failed to load prompts from %@. Falling back to empty list. Error: %@", promptsFileURL.path, String(describing: error))
            prompts = []
            loadFailureMessage = "Prompt Palette couldn't read \(promptsFileURL.path). Check the file contents or restore it from a backup."
        }
    }

    func save() throws {
        try validateTree(prompts)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try JSONEncoder.promptPaletteEncoder.encode(prompts)
        try data.write(to: promptsFileURL, options: .atomic)
    }

    @discardableResult
    func addPrompt(title: String, content: String, parentID: UUID? = nil) throws -> PromptItem {
        let validatedTitle = try validateTitle(title)
        let validatedContent = try validateContent(content)
        let now = Date()
        let prompt = PromptItem(
            id: UUID(),
            title: validatedTitle,
            content: validatedContent,
            children: nil,
            createdAt: now,
            updatedAt: now
        )

        try insertNewItem(prompt, into: parentID, at: nil)
        try save()
        return prompt
    }

    @discardableResult
    func addFolder(title: String, parentID: UUID? = nil) throws -> PromptItem {
        let validatedTitle = try validateTitle(title)
        let now = Date()
        let folder = PromptItem(
            id: UUID(),
            title: validatedTitle,
            content: nil,
            children: [],
            createdAt: now,
            updatedAt: now
        )

        try insertNewItem(folder, into: parentID, at: nil)
        try save()
        return folder
    }

    @discardableResult
    func createPlaceholderPrompt(parentID: UUID? = nil) throws -> PromptItem {
        let now = Date()
        let prompt = PromptItem(
            id: UUID(),
            title: "Untitled Prompt",
            content: " ",
            children: nil,
            createdAt: now,
            updatedAt: now
        )
        try insertNewItem(prompt, into: parentID, at: nil)
        return prompt
    }

    @discardableResult
    func createPlaceholderFolder(parentID: UUID? = nil) throws -> PromptItem {
        let now = Date()
        let folder = PromptItem(
            id: UUID(),
            title: "Untitled Folder",
            content: nil,
            children: [],
            createdAt: now,
            updatedAt: now
        )
        try insertNewItem(folder, into: parentID, at: nil)
        return folder
    }

    func updatePrompt(id: UUID, title: String, content: String) throws {
        let validatedTitle = try validateTitle(title)
        let validatedContent = try validateContent(content)

        try mutateItem(id: id) { item in
            guard item.isPrompt else {
                throw PromptStoreError.invalidPromptState
            }

            item.title = validatedTitle
            item.content = validatedContent
            item.updatedAt = Date()
        }
        try save()
    }

    func updateFolderTitle(id: UUID, title: String) throws {
        let validatedTitle = try validateTitle(title)

        try mutateItem(id: id) { item in
            guard item.isFolder else {
                throw PromptStoreError.invalidFolder
            }

            item.title = validatedTitle
            item.updatedAt = Date()
        }
        try save()
    }

    func incrementUseCount(id: UUID) throws {
        try mutateItem(id: id) { item in
            guard item.isPrompt else {
                throw PromptStoreError.invalidPromptState
            }

            item.useCount += 1
        }
        try save()
    }

    func deleteItem(id: UUID) throws {
        guard removeItem(id: id) != nil else {
            throw PromptStoreError.itemNotFound
        }

        try save()
    }

    func moveItem(id: UUID, destinationParentID: UUID?, insertionIndex: Int) throws {
        let adjustedInsertionIndex = try adjustedInsertionIndexForMove(
            id: id,
            destinationParentID: destinationParentID,
            insertionIndex: insertionIndex
        )

        guard let extracted = removeItem(id: id) else {
            throw PromptStoreError.itemNotFound
        }

        try insertItem(extracted, into: destinationParentID, at: adjustedInsertionIndex)
        try updateFolderTimestamp(id: destinationParentID)
        try save()
    }

    func item(withID id: UUID) -> PromptItem? {
        guard let path = path(for: id) else {
            return nil
        }

        return item(at: path, in: prompts)
    }

    func parentID(of id: UUID) -> UUID? {
        guard let path = path(for: id), path.isEmpty == false else {
            return nil
        }

        let parentPath = Array(path.dropLast())
        return item(at: parentPath, in: prompts)?.id
    }

    func childCount(of parentID: UUID?) -> Int {
        if let parentID {
            return item(withID: parentID)?.children?.count ?? 0
        }

        return prompts.count
    }

    func canCreateItem(in parentID: UUID?) -> Bool {
        do {
            try validateParent(parentID, additionalChildren: 1)
            return true
        } catch {
            return false
        }
    }

    func canMoveItem(id: UUID, toParent destinationParentID: UUID?, insertionIndex: Int) -> Bool {
        do {
            _ = try adjustedInsertionIndexForMove(
                id: id,
                destinationParentID: destinationParentID,
                insertionIndex: insertionIndex
            )
            return true
        } catch {
            return false
        }
    }

    func path(for id: UUID) -> ItemPath? {
        path(for: id, in: prompts, currentPath: [])
    }

    private func insertNewItem(_ item: PromptItem, into parentID: UUID?, at index: Int?) throws {
        try validateParent(parentID, additionalChildren: 1)
        try insertItem(item, into: parentID, at: index)
        try updateFolderTimestamp(id: parentID)
    }

    private func insertItem(_ item: PromptItem, into parentID: UUID?, at index: Int?) throws {
        try mutateChildren(of: parentID) { items in
            let insertionIndex = index ?? items.count
            guard insertionIndex >= 0, insertionIndex <= items.count else {
                throw PromptStoreError.invalidMoveDestination
            }

            items.insert(item, at: insertionIndex)
        }
    }

    private func validateParent(_ parentID: UUID?, additionalChildren: Int) throws {
        if let parentID {
            guard let parent = item(withID: parentID) else {
                throw PromptStoreError.invalidFolder
            }
            guard parent.isFolder else {
                throw PromptStoreError.invalidFolder
            }

            let parentDepth = depth(of: parentID)
            guard parentDepth < Self.maxDepth else {
                throw PromptStoreError.maxDepthExceeded
            }

            let existingChildren = parent.children?.count ?? 0
            guard existingChildren + additionalChildren <= Self.maxChildrenPerParent else {
                throw PromptStoreError.childLimitExceeded
            }
        } else {
            guard prompts.count + additionalChildren <= Self.maxChildrenPerParent else {
                throw PromptStoreError.childLimitExceeded
            }
        }
    }

    private func adjustedInsertionIndexForMove(id: UUID, destinationParentID: UUID?, insertionIndex: Int) throws -> Int {
        guard let movingItem = item(withID: id), let movingPath = path(for: id) else {
            throw PromptStoreError.itemNotFound
        }

        if let destinationParentID {
            guard let destinationFolder = item(withID: destinationParentID), destinationFolder.isFolder else {
                throw PromptStoreError.invalidFolder
            }

            if destinationParentID == id {
                throw PromptStoreError.invalidMoveDestination
            }

            if let destinationParentPath = path(for: destinationParentID),
               destinationParentPath.starts(with: movingPath) {
                throw PromptStoreError.invalidMoveDestination
            }

            let destinationDepth = depth(of: destinationParentID) + subtreeDepth(of: movingItem)
            guard destinationDepth <= Self.maxDepth else {
                throw PromptStoreError.maxDepthExceeded
            }
        } else {
            let destinationDepth = subtreeDepth(of: movingItem)
            guard destinationDepth <= Self.maxDepth else {
                throw PromptStoreError.maxDepthExceeded
            }
        }

        let currentParentID = parentID(of: id)
        let movingWithinSameParent = currentParentID == destinationParentID
        let destinationCount = childCount(of: destinationParentID)
        let adjustedCount = movingWithinSameParent ? destinationCount : destinationCount + 1
        guard adjustedCount <= Self.maxChildrenPerParent else {
            throw PromptStoreError.childLimitExceeded
        }

        guard insertionIndex >= 0, insertionIndex <= destinationCount else {
            throw PromptStoreError.invalidMoveDestination
        }

        if movingWithinSameParent, let originalIndex = movingPath.last, originalIndex < insertionIndex {
            return insertionIndex - 1
        }

        return insertionIndex
    }

    private func validateTree(_ items: [PromptItem]) throws {
        guard items.count <= Self.maxChildrenPerParent else {
            throw PromptStoreError.childLimitExceeded
        }

        try validate(items: items, depth: 1)
    }

    private func validate(items: [PromptItem], depth: Int) throws {
        if items.isEmpty {
            return
        }

        guard depth <= Self.maxDepth else {
            throw PromptStoreError.maxDepthExceeded
        }
        guard items.count <= Self.maxChildrenPerParent else {
            throw PromptStoreError.childLimitExceeded
        }

        for item in items {
            let validatedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard validatedTitle.isEmpty == false else {
                throw PromptStoreError.emptyTitle
            }

            if let children = item.children {
                guard item.content == nil else {
                    throw PromptStoreError.invalidPromptState
                }

                try validate(items: children, depth: depth + 1)
            } else if let content = item.content {
                guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                    throw PromptStoreError.emptyContent
                }
            } else {
                throw PromptStoreError.invalidPromptState
            }
        }
    }

    private func depth(of id: UUID) -> Int {
        guard let path = path(for: id) else {
            return 0
        }

        return path.count
    }

    private func subtreeDepth(of item: PromptItem) -> Int {
        guard let children = item.children, children.isEmpty == false else {
            return 1
        }

        return 1 + children.map(subtreeDepth(of:)).max()!
    }

    private func validateTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw PromptStoreError.emptyTitle
        }

        return trimmed
    }

    private func validateContent(_ content: String) throws -> String {
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw PromptStoreError.emptyContent
        }

        return content
    }

    private func mutateItem(id: UUID, mutation: (inout PromptItem) throws -> Void) throws {
        guard let path = path(for: id) else {
            throw PromptStoreError.itemNotFound
        }

        try mutateItem(at: path, in: &prompts, mutation: mutation)
    }

    private func mutateItem(at path: ItemPath, in items: inout [PromptItem], mutation: (inout PromptItem) throws -> Void) throws {
        guard let index = path.first, items.indices.contains(index) else {
            throw PromptStoreError.itemNotFound
        }

        if path.count == 1 {
            try mutation(&items[index])
            return
        }

        guard items[index].children != nil else {
            throw PromptStoreError.invalidFolder
        }

        try mutateItem(at: Array(path.dropFirst()), in: &items[index].children!, mutation: mutation)
    }

    private func mutateChildren(of parentID: UUID?, mutation: (inout [PromptItem]) throws -> Void) throws {
        if let parentID {
            guard let path = path(for: parentID) else {
                throw PromptStoreError.invalidFolder
            }

            try mutateChildren(at: path, in: &prompts, mutation: mutation)
            return
        }

        try mutation(&prompts)
    }

    private func mutateChildren(at path: ItemPath, in items: inout [PromptItem], mutation: (inout [PromptItem]) throws -> Void) throws {
        guard let index = path.first, items.indices.contains(index) else {
            throw PromptStoreError.invalidFolder
        }

        if path.count == 1 {
            guard items[index].children != nil else {
                throw PromptStoreError.invalidFolder
            }

            try mutation(&items[index].children!)
            items[index].updatedAt = Date()
            return
        }

        guard items[index].children != nil else {
            throw PromptStoreError.invalidFolder
        }

        try mutateChildren(at: Array(path.dropFirst()), in: &items[index].children!, mutation: mutation)
    }

    @discardableResult
    private func removeItem(id: UUID) -> PromptItem? {
        removeItem(id: id, from: &prompts)
    }

    @discardableResult
    private func removeItem(id: UUID, from items: inout [PromptItem]) -> PromptItem? {
        if let index = items.firstIndex(where: { $0.id == id }) {
            return items.remove(at: index)
        }

        for index in items.indices {
            if items[index].children != nil,
               let removed = removeItem(id: id, from: &items[index].children!) {
                items[index].updatedAt = Date()
                return removed
            }
        }

        return nil
    }

    private func item(at path: ItemPath, in items: [PromptItem]) -> PromptItem? {
        guard let index = path.first, items.indices.contains(index) else {
            return nil
        }

        let currentItem = items[index]
        if path.count == 1 {
            return currentItem
        }

        guard let children = currentItem.children else {
            return nil
        }

        return self.item(at: Array(path.dropFirst()), in: children)
    }

    private func path(for id: UUID, in items: [PromptItem], currentPath: ItemPath) -> ItemPath? {
        for (index, item) in items.enumerated() {
            let nextPath = currentPath + [index]
            if item.id == id {
                return nextPath
            }

            if let children = item.children,
               let childPath = path(for: id, in: children, currentPath: nextPath) {
                return childPath
            }
        }

        return nil
    }

    private func updateFolderTimestamp(id: UUID?) throws {
        guard let id else {
            return
        }

        try mutateItem(id: id) { item in
            guard item.isFolder else {
                throw PromptStoreError.invalidFolder
            }

            item.updatedAt = Date()
        }
    }
}

extension JSONDecoder {
    static let promptPaletteDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let promptPaletteEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
