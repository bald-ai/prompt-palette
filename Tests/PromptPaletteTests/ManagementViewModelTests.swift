import XCTest
@testable import PromptPalette

@MainActor
final class ManagementViewModelTests: XCTestCase {
    func testCreatingPromptInsideSelectedFolderUsesFolderAsParent() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)
        viewModel.requestCreateNewPrompt()
        viewModel.draftTitle = "Child"
        viewModel.draftContent = "Prompt"
        viewModel.saveChanges()

        XCTAssertEqual(store.item(withID: folder.id)?.children?.map(\.title), ["Child"])
    }

    func testCreatingPromptWithSelectedPromptUsesSiblingParent() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let firstPrompt = try store.addPrompt(title: "One", content: "1", parentID: folder.id)
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(firstPrompt.id)
        viewModel.requestCreateNewPrompt()
        viewModel.draftTitle = "Two"
        viewModel.draftContent = "2"
        viewModel.saveChanges()

        XCTAssertEqual(store.item(withID: folder.id)?.children?.map(\.title), ["One", "Two"])
    }

    func testCreatingFolderWithoutSelectionUsesRoot() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestCreateNewFolder()
        viewModel.draftTitle = "Root Folder"
        viewModel.saveChanges()

        XCTAssertEqual(store.prompts.map(\.title), ["Root Folder"])
    }

    func testNonEmptyFolderDeleteShowsConfirmation() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        try store.addPrompt(title: "Child", content: "Prompt", parentID: folder.id)
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)
        viewModel.requestDeleteSelectedItem()

        XCTAssertTrue(viewModel.showingDeleteConfirmation)
        XCTAssertTrue(viewModel.deleteConfirmationMessage.contains("1 nested items"))
    }

    func testEditingModeSwitchesBetweenPromptAndFolder() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let prompt = try store.addPrompt(title: "Prompt", content: "Content")
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)
        XCTAssertFalse(viewModel.isEditingPrompt)

        viewModel.requestSelection(prompt.id)
        XCTAssertTrue(viewModel.isEditingPrompt)
    }

    func testDragValidationRejectsMovingFolderIntoOwnDescendant() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let parent = try store.addFolder(title: "Parent")
        let child = try store.addFolder(title: "Child", parentID: parent.id)
        let viewModel = ManagementViewModel(store: store)

        viewModel.beginDragging(itemID: parent.id)

        XCTAssertFalse(viewModel.canAcceptDrop(destinationParentID: child.id, insertionIndex: 0))
    }

    func testWindowClosingDeletesUnsavedPlaceholder() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestCreateNewPrompt()
        viewModel.draftTitle = "Draft Prompt"
        viewModel.draftContent = "Draft Content"

        XCTAssertEqual(store.prompts.count, 1)

        viewModel.handleWindowClosing()

        XCTAssertTrue(store.prompts.isEmpty)
        XCTAssertNil(viewModel.placeholderItemID)
    }

    func testEnterTogglesSelectedFolderExpansion() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)

        XCTAssertTrue(viewModel.isFolderExpanded(folder.id))

        viewModel.toggleSelectedFolderExpansion()
        XCTAssertFalse(viewModel.isFolderExpanded(folder.id))

        viewModel.toggleSelectedFolderExpansion()
        XCTAssertTrue(viewModel.isFolderExpanded(folder.id))
    }

    func testDownArrowOpensClosedFolderBeforeMovingSelectionIntoChildren() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let child = try store.addPrompt(title: "Child", content: "Prompt", parentID: folder.id)
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)
        viewModel.toggleSelectedFolderExpansion()

        viewModel.moveSelectionDown()
        XCTAssertTrue(viewModel.isFolderExpanded(folder.id))
        XCTAssertEqual(viewModel.selectedItemID, folder.id)

        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedItemID, child.id)
    }

    func testUpArrowClosesOpenFolderBeforeMovingSelectionUp() throws {
        let store = PromptStore(directoryURL: try makeTemporaryDirectory())
        let folder = try store.addFolder(title: "Folder")
        let prompt = try store.addPrompt(title: "Prompt", content: "Prompt")
        let viewModel = ManagementViewModel(store: store)

        viewModel.requestSelection(folder.id)
        XCTAssertTrue(viewModel.isFolderExpanded(folder.id))

        viewModel.moveSelectionUp()
        XCTAssertFalse(viewModel.isFolderExpanded(folder.id))

        viewModel.moveSelectionDown()
        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedItemID, prompt.id)

        viewModel.moveSelectionUp()
        XCTAssertEqual(viewModel.selectedItemID, folder.id)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
