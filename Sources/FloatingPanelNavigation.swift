import Foundation

enum PickerTransitionDirection {
    case forward
    case backward
}

struct PickerNavigationState {
    private(set) var rootItems: [PromptItem] = []
    private(set) var stack: [PromptItem] = []

    /// Live search text. Empty when not filtering.
    var searchQuery: String = ""

    var currentItems: [PromptItem] {
        stack.last?.children ?? rootItems
    }

    /// Items shown to the user — filtered by `searchQuery` when present.
    var displayedItems: [PromptItem] {
        guard searchQuery.isEmpty == false else {
            return currentItems
        }

        let query = searchQuery.lowercased()
        return currentItems.filter { $0.title.lowercased().contains(query) }
    }

    var isNested: Bool {
        stack.isEmpty == false
    }

    var currentTitle: String {
        stack.last?.title ?? "Prompt Palette"
    }

    mutating func show(rootItems: [PromptItem]) {
        self.rootItems = rootItems
        stack = []
        searchQuery = ""
    }

    /// Open a folder (pushes it on the stack, returns nil) or return a prompt to run.
    mutating func enter(_ item: PromptItem) -> PromptItem? {
        if item.isFolder {
            stack.append(item)
            searchQuery = ""
            return nil
        }

        return item
    }

    @discardableResult
    mutating func goBack() -> Bool {
        guard stack.isEmpty == false else {
            return false
        }

        stack.removeLast()
        return true
    }

    func footerText(backKeyDisplay: String, isSearching: Bool) -> String {
        if isSearching {
            return "↑↓ ↩ select · \(backKeyDisplay) exit search · esc dismiss"
        }

        return isNested
            ? "↑↓ ↩ select · \(backKeyDisplay) back · esc dismiss"
            : "↑↓ ↩ select · tab to search · esc dismiss"
    }
}
