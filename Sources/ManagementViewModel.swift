import Combine
import Foundation

struct ManagementRow: Identifiable, Equatable {
    let item: PromptItem
    let depth: Int
    let parentID: UUID?
    let indexInParent: Int

    var id: UUID { item.id }
}

@MainActor
final class ManagementViewModel: ObservableObject {
    enum DraftKind {
        case prompt
        case folder
    }

    @Published var selectedItemID: UUID?
    @Published var draftTitle = ""
    @Published var draftContent = ""
    @Published var expandedFolderIDs: Set<UUID> = []
    @Published var validationMessage: String?
    @Published var showingDiscardAlert = false
    @Published var showingDeleteConfirmation = false
    @Published var deleteConfirmationMessage = ""

    let store: PromptStore

    private var pendingAction: PendingAction?
    private(set) var draftKind: DraftKind?
    private(set) var placeholderItemID: UUID?
    private var draggedItemID: UUID?

    init(store: PromptStore) {
        self.store = store
        expandedFolderIDs = Set(store.prompts.filter(\.isFolder).map(\.id))
    }

    var selectedItem: PromptItem? {
        guard let selectedItemID else {
            return nil
        }

        return store.item(withID: selectedItemID)
    }

    var isEditingPlaceholder: Bool {
        placeholderItemID != nil
    }

    var visibleRows: [ManagementRow] {
        flatten(items: store.prompts, parentID: nil, depth: 0)
    }

    var hasSelection: Bool {
        selectedItem != nil
    }

    var canDelete: Bool {
        guard let selectedItem else {
            return false
        }

        return placeholderItemID != selectedItem.id
    }

    var canCreateInTargetParent: Bool {
        store.canCreateItem(in: currentCreationTargetParentID)
    }

    var editorHeading: String {
        if isEditingPlaceholder {
            return draftKind == .folder ? "New Folder" : "New Prompt"
        }

        switch draftKind {
        case .folder:
            return "Edit Folder"
        case .prompt:
            return "Edit Prompt"
        case .none:
            return "Select an Item"
        }
    }

    var isEditingPrompt: Bool {
        draftKind == .prompt
    }

    var promptUsageText: String? {
        guard isEditingPrompt,
              isEditingPlaceholder == false,
              let selectedItem,
              selectedItem.isPrompt else {
            return nil
        }

        return selectedItem.useCount == 0 ? "Never used" : "Used \(selectedItem.useCount) time\(selectedItem.useCount == 1 ? "" : "s")"
    }

    /// "Prompt" or "Folder" — kind label for the editor crumb and pill.
    var editorKindLabel: String {
        isEditingPrompt ? "Prompt" : "Folder"
    }

    /// Title of the parent folder, shown in the editor breadcrumb (nil at root).
    var editorParentTitle: String? {
        guard let selectedItemID,
              let parentID = store.parentID(of: selectedItemID) else {
            return nil
        }

        return store.item(withID: parentID)?.title
    }

    /// Number of direct children when editing a folder (nil for prompts).
    var folderChildCount: Int? {
        guard isEditingPrompt == false,
              isEditingPlaceholder == false,
              let selectedItem,
              selectedItem.isFolder else {
            return nil
        }

        return selectedItem.children?.count ?? 0
    }

    var hasUnsavedChanges: Bool {
        if isEditingPlaceholder {
            return draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                || (draftKind == .prompt && draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }

        guard let selectedItem, let draftKind else {
            return false
        }

        switch draftKind {
        case .prompt:
            return draftTitle != selectedItem.title || draftContent != (selectedItem.content ?? "")
        case .folder:
            return draftTitle != selectedItem.title
        }
    }

    private var currentCreationTargetParentID: UUID? {
        if let selectedItem, selectedItem.isFolder, placeholderItemID != selectedItem.id {
            return selectedItem.id
        }

        if let selectedItemID {
            return store.parentID(of: selectedItemID)
        }

        return nil
    }

    func ensureInitialSelection() {
        guard placeholderItemID == nil else {
            return
        }

        if let selectedItemID, store.item(withID: selectedItemID) != nil {
            loadDraft(for: selectedItemID)
            return
        }

        guard let firstItem = store.prompts.first else {
            clearEditor()
            return
        }

        applySelection(firstItem.id)
    }

    func handlePromptsChanged() {
        expandedFolderIDs = expandedFolderIDs.intersection(Set(allFolderIDs(in: store.prompts)))

        if placeholderItemID != nil {
            return
        }

        guard let selectedItemID else {
            if let firstItem = store.prompts.first {
                applySelection(firstItem.id)
            } else {
                clearEditor()
            }
            return
        }

        if store.item(withID: selectedItemID) == nil {
            if let firstItem = store.prompts.first {
                applySelection(firstItem.id)
            } else {
                clearEditor()
            }
            return
        }

        if hasUnsavedChanges == false {
            loadDraft(for: selectedItemID)
        }
    }

    func handleWindowClosing() {
        clearTransientUiState()
        cancelEditing()
    }

    func requestSelection(_ itemID: UUID?) {
        guard itemID != selectedItemID || placeholderItemID != nil else {
            return
        }

        if placeholderItemID != nil {
            deletePlaceholder()
        } else if hasUnsavedChanges {
            pendingAction = .select(itemID)
            showingDiscardAlert = true
            return
        }

        applySelection(itemID)
    }

    func requestCreateNewPrompt() {
        requestCreateNewItem(kind: .prompt)
    }

    func requestCreateNewFolder() {
        requestCreateNewItem(kind: .folder)
    }

    func requestDeleteSelectedItem() {
        guard canDelete, selectedItem != nil else {
            return
        }

        if hasUnsavedChanges {
            pendingAction = .deleteSelected
            showingDiscardAlert = true
            return
        }

        continueDeleteRequest()
    }

    func confirmDeleteSelectedItem() {
        showingDeleteConfirmation = false
        performDeleteSelectedItem()
    }

    func confirmDiscardChanges() {
        let action = pendingAction
        pendingAction = nil
        showingDiscardAlert = false

        switch action {
        case .select(let itemID):
            applySelection(itemID)
        case .create(let kind):
            startCreatingNewItem(kind: kind)
        case .deleteSelected:
            continueDeleteRequest()
        case .none:
            break
        }
    }

    func cancelEditing() {
        validationMessage = nil

        if placeholderItemID != nil {
            deletePlaceholder()
            ensureInitialSelection()
            return
        }

        if let selectedItemID {
            loadDraft(for: selectedItemID)
        } else {
            clearEditor()
        }
    }

    func saveChanges() {
        validationMessage = nil

        do {
            if let placeholderID = placeholderItemID {
                switch draftKind {
                case .prompt:
                    try store.updatePrompt(id: placeholderID, title: draftTitle, content: draftContent)
                case .folder:
                    try store.updateFolderTitle(id: placeholderID, title: draftTitle)
                case .none:
                    break
                }

                try store.save()
                placeholderItemID = nil
                loadDraft(for: placeholderID)
            } else if let selectedItemID, let draftKind {
                switch draftKind {
                case .prompt:
                    try store.updatePrompt(id: selectedItemID, title: draftTitle, content: draftContent)
                case .folder:
                    try store.updateFolderTitle(id: selectedItemID, title: draftTitle)
                }

                loadDraft(for: selectedItemID)
            }
        } catch let error as PromptStoreError {
            validationMessage = error.errorDescription
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    func toggleFolderExpansion(_ folderID: UUID) {
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    func isFolderExpanded(_ folderID: UUID) -> Bool {
        expandedFolderIDs.contains(folderID)
    }

    func toggleSelectedFolderExpansion() {
        guard let selectedItem, selectedItem.isFolder else {
            return
        }

        toggleFolderExpansion(selectedItem.id)
    }

    func moveSelectionDown() {
        guard let selectedItemID,
              let selectedRowIndex = visibleRows.firstIndex(where: { $0.item.id == selectedItemID }) else {
            ensureInitialSelection()
            return
        }

        let selectedRow = visibleRows[selectedRowIndex]
        if selectedRow.item.isFolder,
           isFolderExpanded(selectedRow.item.id) == false,
           selectedRow.item.children?.isEmpty == false {
            expandedFolderIDs.insert(selectedRow.item.id)
            return
        }

        let rowsAfterExpansion = visibleRows
        guard let currentIndex = rowsAfterExpansion.firstIndex(where: { $0.item.id == selectedItemID }),
              rowsAfterExpansion.indices.contains(currentIndex + 1) else {
            return
        }

        requestSelection(rowsAfterExpansion[currentIndex + 1].item.id)
    }

    func moveSelectionUp() {
        guard let selectedItemID,
              let selectedRowIndex = visibleRows.firstIndex(where: { $0.item.id == selectedItemID }) else {
            ensureInitialSelection()
            return
        }

        let selectedRow = visibleRows[selectedRowIndex]
        if selectedRow.item.isFolder,
           isFolderExpanded(selectedRow.item.id) {
            expandedFolderIDs.remove(selectedRow.item.id)
            return
        }

        guard selectedRowIndex > 0 else {
            return
        }

        requestSelection(visibleRows[selectedRowIndex - 1].item.id)
    }

    func beginDragging(itemID: UUID) {
        draggedItemID = itemID
    }

    func canAcceptDrop(destinationParentID: UUID?, insertionIndex: Int) -> Bool {
        guard let draggedItemID else {
            return false
        }

        return store.canMoveItem(id: draggedItemID, toParent: destinationParentID, insertionIndex: insertionIndex)
    }

    func performDrop(destinationParentID: UUID?, insertionIndex: Int) -> Bool {
        guard let draggedItemID else {
            return false
        }

        do {
            try store.moveItem(id: draggedItemID, destinationParentID: destinationParentID, insertionIndex: insertionIndex)
            if let destinationParentID {
                expandedFolderIDs.insert(destinationParentID)
            }
            selectedItemID = draggedItemID
            loadDraft(for: draggedItemID)
            clearDragState()
            return true
        } catch {
            validationMessage = error.localizedDescription
            clearDragState()
            return false
        }
    }

    private func requestCreateNewItem(kind: DraftKind) {
        guard store.canCreateItem(in: currentCreationTargetParentID) else {
            return
        }

        if placeholderItemID != nil {
            deletePlaceholder()
        } else if hasUnsavedChanges {
            pendingAction = .create(kind)
            showingDiscardAlert = true
            return
        }

        startCreatingNewItem(kind: kind)
    }

    private func startCreatingNewItem(kind: DraftKind) {
        let parentID = currentCreationTargetParentID
        validationMessage = nil

        do {
            let placeholder: PromptItem
            switch kind {
            case .prompt:
                placeholder = try store.createPlaceholderPrompt(parentID: parentID)
            case .folder:
                placeholder = try store.createPlaceholderFolder(parentID: parentID)
            }

            placeholderItemID = placeholder.id
            draftKind = kind
            selectedItemID = placeholder.id
            draftTitle = ""
            draftContent = ""

            if let parentID {
                expandedFolderIDs.insert(parentID)
            }
            if placeholder.isFolder {
                expandedFolderIDs.insert(placeholder.id)
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func deletePlaceholder() {
        guard let placeholderID = placeholderItemID else {
            return
        }

        placeholderItemID = nil
        try? store.deleteItem(id: placeholderID)
    }

    private func continueDeleteRequest() {
        guard let selectedItem else {
            return
        }

        validationMessage = nil

        if selectedItem.isFolder, selectedItem.descendantCount > 0 {
            deleteConfirmationMessage = "This folder contains \(selectedItem.descendantCount) nested items. Delete the folder and everything inside it?"
            showingDeleteConfirmation = true
            return
        }

        performDeleteSelectedItem()
    }

    private func performDeleteSelectedItem() {
        guard let selectedItemID else {
            return
        }

        do {
            let parentID = store.parentID(of: selectedItemID)
            try store.deleteItem(id: selectedItemID)
            showingDeleteConfirmation = false

            if let parentID, store.item(withID: parentID) != nil {
                applySelection(parentID)
            } else if let firstItem = store.prompts.first {
                applySelection(firstItem.id)
            } else {
                clearEditor()
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func applySelection(_ itemID: UUID?) {
        pendingAction = nil
        showingDiscardAlert = false
        validationMessage = nil
        placeholderItemID = nil
        draftKind = nil
        selectedItemID = itemID

        guard let itemID else {
            clearEditor()
            return
        }

        loadDraft(for: itemID)
    }

    private func loadDraft(for itemID: UUID) {
        guard let item = store.item(withID: itemID) else {
            clearEditor()
            return
        }

        selectedItemID = item.id
        draftTitle = item.title
        draftContent = item.content ?? ""
        draftKind = item.isFolder ? .folder : .prompt
    }

    private func clearEditor() {
        selectedItemID = nil
        draftTitle = ""
        draftContent = ""
        draftKind = nil
        placeholderItemID = nil
    }

    private func clearDragState() {
        draggedItemID = nil
    }

    private func clearTransientUiState() {
        pendingAction = nil
        showingDiscardAlert = false
        showingDeleteConfirmation = false
        clearDragState()
    }

    private func flatten(items: [PromptItem], parentID: UUID?, depth: Int) -> [ManagementRow] {
        var rows: [ManagementRow] = []

        for (index, item) in items.enumerated() {
            rows.append(ManagementRow(item: item, depth: depth, parentID: parentID, indexInParent: index))
            if let children = item.children, expandedFolderIDs.contains(item.id) {
                rows.append(contentsOf: flatten(items: children, parentID: item.id, depth: depth + 1))
            }
        }

        return rows
    }

    private func allFolderIDs(in items: [PromptItem]) -> [UUID] {
        items.flatMap { item in
            guard let children = item.children else {
                return [UUID]()
            }

            return [item.id] + allFolderIDs(in: children)
        }
    }

    private enum PendingAction {
        case select(UUID?)
        case create(DraftKind)
        case deleteSelected
    }
}
