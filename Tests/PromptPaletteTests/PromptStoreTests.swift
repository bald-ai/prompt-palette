import XCTest
@testable import PromptPalette

@MainActor
final class PromptStoreTests: XCTestCase {
    func testLoadMissingFileReturnsEmptyList() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)

        store.load()

        XCTAssertTrue(store.prompts.isEmpty)
    }

    func testLoadValidLegacyJSONReturnsPromptsInOrder() throws {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("prompts.json")
        let legacyJSON = """
        [
          {
            "id": "\(UUID().uuidString)",
            "title": "One",
            "content": "First",
            "createdAt": "2026-04-14T12:00:00Z",
            "updatedAt": "2026-04-14T12:00:00Z"
          },
          {
            "id": "\(UUID().uuidString)",
            "title": "Two",
            "content": "Second",
            "createdAt": "2026-04-14T12:00:00Z",
            "updatedAt": "2026-04-14T12:00:00Z"
          }
        ]
        """
        try Data(legacyJSON.utf8).write(to: fileURL)

        let store = PromptStore(directoryURL: directory)
        store.load()

        XCTAssertEqual(store.prompts.map(\.title), ["One", "Two"])
        XCTAssertTrue(store.prompts.allSatisfy(\.isPrompt))
        XCTAssertEqual(store.prompts.map(\.useCount), [0, 0])
    }

    func testLoadCorruptJSONReturnsEmptyList() throws {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("prompts.json")
        try Data("{not valid json}".utf8).write(to: fileURL)

        let store = PromptStore(directoryURL: directory)
        store.load()

        XCTAssertEqual(store.prompts, [])
        XCTAssertNotNil(store.loadFailureMessage)
    }

    func testLoadInvalidTreeReturnsEmptyList() throws {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("prompts.json")
        let invalidJSON = """
        [
          {
            "id": "\(UUID().uuidString)",
            "title": "Broken",
            "content": "Prompt",
            "children": [],
            "createdAt": "2026-04-14T12:00:00Z",
            "updatedAt": "2026-04-14T12:00:00Z"
          }
        ]
        """
        try Data(invalidJSON.utf8).write(to: fileURL)

        let store = PromptStore(directoryURL: directory)
        store.load()

        XCTAssertTrue(store.prompts.isEmpty)
        XCTAssertNotNil(store.loadFailureMessage)
    }

    func testSuccessfulLoadClearsPreviousFailureMessage() throws {
        let directory = try makeTemporaryDirectory()
        let fileURL = directory.appendingPathComponent("prompts.json")
        try Data("{not valid json}".utf8).write(to: fileURL)

        let store = PromptStore(directoryURL: directory)
        store.load()
        XCTAssertNotNil(store.loadFailureMessage)

        let items = [
            PromptItem(id: UUID(), title: "One", content: "First", children: nil, createdAt: Date(), updatedAt: Date()),
        ]
        let data = try JSONEncoder.promptPaletteEncoder.encode(items)
        try data.write(to: fileURL, options: .atomic)

        store.load()

        XCTAssertEqual(store.prompts.map(\.title), ["One"])
        XCTAssertNil(store.loadFailureMessage)
    }

    func testAddFolderAndPromptInsideItPersist() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let folder = try store.addFolder(title: "Code Review")

        try store.addPrompt(title: "Checklist", content: "Review this PR carefully.", parentID: folder.id)

        let reloadedStore = PromptStore(directoryURL: directory)
        reloadedStore.load()

        XCTAssertEqual(reloadedStore.prompts.count, 1)
        XCTAssertEqual(reloadedStore.prompts.first?.title, "Code Review")
        XCTAssertEqual(reloadedStore.prompts.first?.children?.first?.title, "Checklist")
    }

    func testUpdatePromptChangesContentAndUpdatedAt() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let prompt = try store.addPrompt(title: "Title", content: "Old")
        let originalUpdatedAt = try XCTUnwrap(store.prompts.first?.updatedAt)

        try store.updatePrompt(id: prompt.id, title: "Updated", content: "New")

        let updatedPrompt = try XCTUnwrap(store.prompts.first)
        XCTAssertEqual(updatedPrompt.title, "Updated")
        XCTAssertEqual(updatedPrompt.content, "New")
        XCTAssertGreaterThanOrEqual(updatedPrompt.updatedAt, originalUpdatedAt)
    }

    func testIncrementUseCountPersistsAcrossReload() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let prompt = try store.addPrompt(title: "Frequently Used", content: "Prompt body")

        try store.incrementUseCount(id: prompt.id)
        try store.incrementUseCount(id: prompt.id)

        XCTAssertEqual(store.item(withID: prompt.id)?.useCount, 2)

        let reloadedStore = PromptStore(directoryURL: directory)
        reloadedStore.load()

        XCTAssertEqual(reloadedStore.item(withID: prompt.id)?.useCount, 2)
    }

    func testMovePromptIntoFolder() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let prompt = try store.addPrompt(title: "Move Me", content: "Prompt")
        let folder = try store.addFolder(title: "Folder")

        try store.moveItem(id: prompt.id, destinationParentID: folder.id, insertionIndex: 0)

        XCTAssertEqual(store.prompts.count, 1)
        XCTAssertEqual(store.prompts.first?.title, "Folder")
        XCTAssertEqual(store.prompts.first?.children?.map(\.title), ["Move Me"])
    }

    func testMoveItemWithinSameParentAdjustsInsertionIndex() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let folder = try store.addFolder(title: "Folder")
        let one = try store.addPrompt(title: "One", content: "1", parentID: folder.id)
        _ = try store.addPrompt(title: "Two", content: "2", parentID: folder.id)
        _ = try store.addPrompt(title: "Three", content: "3", parentID: folder.id)

        try store.moveItem(id: one.id, destinationParentID: folder.id, insertionIndex: 3)

        let items = try XCTUnwrap(store.item(withID: folder.id)?.children)
        XCTAssertEqual(items.map(\.title), ["Two", "Three", "One"])
    }

    func testMoveToDifferentParentRejectsInsertionPastEndWithoutRemovingItem() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let sourceFolder = try store.addFolder(title: "Source")
        let destinationFolder = try store.addFolder(title: "Destination")
        let prompt = try store.addPrompt(title: "Move Me", content: "Prompt", parentID: sourceFolder.id)

        XCTAssertFalse(store.canMoveItem(id: prompt.id, toParent: destinationFolder.id, insertionIndex: 1))
        XCTAssertThrowsError(try store.moveItem(id: prompt.id, destinationParentID: destinationFolder.id, insertionIndex: 1)) { error in
            XCTAssertEqual(error as? PromptStoreError, .invalidMoveDestination)
        }

        XCTAssertEqual(store.item(withID: sourceFolder.id)?.children?.map(\.title), ["Move Me"])
        XCTAssertEqual(store.item(withID: destinationFolder.id)?.children?.map(\.title), [])
        XCTAssertEqual(store.item(withID: prompt.id)?.title, "Move Me")
    }

    func testDeleteFolderRemovesWholeBranch() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let folder = try store.addFolder(title: "Folder")
        try store.addPrompt(title: "Child", content: "1", parentID: folder.id)

        try store.deleteItem(id: folder.id)

        XCTAssertTrue(store.prompts.isEmpty)
    }

    func testAddPromptRejectsEmptyTitle() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)

        XCTAssertThrowsError(try store.addPrompt(title: "   ", content: "Content")) { error in
            XCTAssertEqual(error as? PromptStoreError, .emptyTitle)
        }
    }

    func testAddPromptRejectsEmptyContent() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)

        XCTAssertThrowsError(try store.addPrompt(title: "Title", content: "\n")) { error in
            XCTAssertEqual(error as? PromptStoreError, .emptyContent)
        }
    }

    func testRootCannotExceedNineItems() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)

        for index in 1...9 {
            try store.addPrompt(title: "Prompt \(index)", content: "Content \(index)")
        }

        XCTAssertThrowsError(try store.addPrompt(title: "Prompt 10", content: "Content 10")) { error in
            XCTAssertEqual(error as? PromptStoreError, .childLimitExceeded)
        }
    }

    func testFolderCannotExceedNineChildren() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let folder = try store.addFolder(title: "Folder")

        for index in 1...9 {
            try store.addPrompt(title: "Prompt \(index)", content: "Content \(index)", parentID: folder.id)
        }

        XCTAssertThrowsError(try store.addPrompt(title: "Prompt 10", content: "Content 10", parentID: folder.id)) { error in
            XCTAssertEqual(error as? PromptStoreError, .childLimitExceeded)
        }
    }

    func testNestingCannotExceedFiveLevels() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let level1 = try store.addFolder(title: "Level 1")
        let level2 = try store.addFolder(title: "Level 2", parentID: level1.id)
        let level3 = try store.addFolder(title: "Level 3", parentID: level2.id)
        let level4 = try store.addFolder(title: "Level 4", parentID: level3.id)
        let level5 = try store.addFolder(title: "Level 5", parentID: level4.id)

        XCTAssertThrowsError(try store.addPrompt(title: "Too Deep", content: "Prompt", parentID: level5.id)) { error in
            XCTAssertEqual(error as? PromptStoreError, .maxDepthExceeded)
        }
    }

    func testMultilineContentRoundTrips() throws {
        let directory = try makeTemporaryDirectory()
        let store = PromptStore(directoryURL: directory)
        let content = """
        Line one
        Line two
        Line three
        """

        try store.addPrompt(title: "Multiline", content: content)

        let reloadedStore = PromptStore(directoryURL: directory)
        reloadedStore.load()
        XCTAssertEqual(reloadedStore.prompts.first?.content, content)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
