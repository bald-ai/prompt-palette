import XCTest
@testable import PromptPalette

final class FloatingPanelNavigationTests: XCTestCase {
    func testSelectingFolderDrillsInAndSelectingPromptReturnsPrompt() {
        let prompt = makePrompt(title: "Leaf")
        let folder = makeFolder(title: "Folder", children: [prompt])
        var state = PickerNavigationState()

        state.show(rootItems: [folder])
        let folderSelection = state.enter(folder)

        XCTAssertNil(folderSelection)
        XCTAssertTrue(state.isNested)
        XCTAssertEqual(state.currentItems.map(\.title), ["Leaf"])

        let promptSelection = state.enter(prompt)
        XCTAssertEqual(promptSelection?.title, "Leaf")
    }

    func testBackAtRootIsNoOp() {
        var state = PickerNavigationState()
        state.show(rootItems: [makePrompt(title: "One")])

        XCTAssertFalse(state.goBack())
        XCTAssertFalse(state.isNested)
    }

    func testShowResetsToRoot() {
        let folder = makeFolder(title: "Folder", children: [makePrompt(title: "Leaf")])
        var state = PickerNavigationState()
        state.show(rootItems: [folder])
        _ = state.enter(folder)

        XCTAssertTrue(state.isNested)

        state.show(rootItems: [makePrompt(title: "Root")])

        XCTAssertFalse(state.isNested)
        XCTAssertEqual(state.currentItems.map(\.title), ["Root"])
    }

    func testFooterTextChangesByDepth() {
        let folder = makeFolder(title: "Folder", children: [])
        var state = PickerNavigationState()
        state.show(rootItems: [folder])

        XCTAssertEqual(state.footerText(backKeyDisplay: "§", isSearching: false), "↑↓ ↩ select · tab to search · esc dismiss")

        _ = state.enter(folder)

        XCTAssertEqual(state.footerText(backKeyDisplay: "§", isSearching: false), "↑↓ ↩ select · § back · esc dismiss")
        XCTAssertTrue(state.currentItems.isEmpty)
    }

    func testFooterTextInSearchMode() {
        var state = PickerNavigationState()
        state.show(rootItems: [makePrompt(title: "One")])

        XCTAssertEqual(
            state.footerText(backKeyDisplay: "§", isSearching: true),
            "↑↓ ↩ select · § exit search · esc dismiss"
        )
    }

    func testSearchQueryFiltersDisplayedItems() {
        var state = PickerNavigationState()
        state.show(rootItems: [
            makePrompt(title: "Summarize thread"),
            makePrompt(title: "Fix grammar"),
            makePrompt(title: "Summarize email"),
        ])

        state.searchQuery = "summ"

        XCTAssertEqual(state.displayedItems.map(\.title), ["Summarize thread", "Summarize email"])
        // Underlying items are untouched by filtering.
        XCTAssertEqual(state.currentItems.count, 3)
    }

    func testEnteringFolderClearsSearchQuery() {
        let folder = makeFolder(title: "Folder", children: [makePrompt(title: "Leaf")])
        var state = PickerNavigationState()
        state.show(rootItems: [folder])
        state.searchQuery = "fol"

        _ = state.enter(folder)

        XCTAssertTrue(state.isNested)
        XCTAssertEqual(state.searchQuery, "")
        XCTAssertEqual(state.displayedItems.map(\.title), ["Leaf"])
    }

    private func makePrompt(title: String) -> PromptItem {
        PromptItem(id: UUID(), title: title, content: title, children: nil, createdAt: Date(), updatedAt: Date())
    }

    private func makeFolder(title: String, children: [PromptItem]) -> PromptItem {
        PromptItem(id: UUID(), title: title, content: nil, children: children, createdAt: Date(), updatedAt: Date())
    }
}
