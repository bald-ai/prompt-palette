import AppKit
import SwiftUI

struct ManagementOutlineView: NSViewRepresentable {
    @ObservedObject var viewModel: ManagementViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = ThemeColors.sidebarBackground

        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.rowHeight = 32
        outlineView.intercellSpacing = NSSize(width: 0, height: 1)
        outlineView.selectionHighlightStyle = .none
        outlineView.allowsEmptySelection = false
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 18
        outlineView.focusRingType = .none
        outlineView.backgroundColor = ThemeColors.sidebarBackground
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.registerForDraggedTypes([.string])
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)

        let column = NSTableColumn(identifier: Coordinator.columnIdentifier)
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.toggleClickedFolder)
        context.coordinator.outlineView = outlineView

        scrollView.documentView = outlineView
        context.coordinator.reload()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.reload()
    }

    @MainActor
    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        static let columnIdentifier = NSUserInterfaceItemIdentifier("PromptColumn")
        private static let rowIdentifier = NSUserInterfaceItemIdentifier("PromptRow")

        weak var outlineView: NSOutlineView?
        var viewModel: ManagementViewModel

        private var rootNodes: [OutlineNode] = []
        private var nodesByID: [UUID: OutlineNode] = [:]
        private var isReloading = false

        init(viewModel: ManagementViewModel) {
            self.viewModel = viewModel
        }

        func reload() {
            rebuildNodes()

            guard let outlineView else {
                return
            }

            isReloading = true
            outlineView.reloadData()
            restoreExpansion(in: outlineView)
            restoreSelection(in: outlineView)
            isReloading = false
        }

        @objc
        func toggleClickedFolder() {
            guard let outlineView,
                  outlineView.clickedRow >= 0,
                  let node = outlineView.item(atRow: outlineView.clickedRow) as? OutlineNode,
                  node.item.isFolder else {
                return
            }

            viewModel.requestSelection(node.item.id)
            viewModel.toggleFolderExpansion(node.item.id)
            reload()
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            node(for: item)?.children.count ?? rootNodes.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (node(for: item)?.children ?? rootNodes)[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = item as? OutlineNode else {
                return false
            }

            return node.item.isFolder
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            viewFor tableColumn: NSTableColumn?,
            item: Any
        ) -> NSView? {
            guard let node = item as? OutlineNode else {
                return nil
            }

            let cell = outlineView.makeView(withIdentifier: Self.rowIdentifier, owner: self) as? PromptOutlineCell
                ?? PromptOutlineCell(identifier: Self.rowIdentifier)
            cell.configure(with: node.item, isSelected: node.item.id == viewModel.selectedItemID)
            return cell
        }

        func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            let isSelected = (item as? OutlineNode)?.item.id == viewModel.selectedItemID
            let rowView = PromptOutlineRowView()
            rowView.isSelectedRow = isSelected
            return rowView
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard isReloading == false,
                  let outlineView,
                  outlineView.selectedRow >= 0,
                  let node = outlineView.item(atRow: outlineView.selectedRow) as? OutlineNode else {
                return
            }

            viewModel.requestSelection(node.item.id)
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            guard isReloading == false,
                  let node = notification.userInfo?["NSObject"] as? OutlineNode else {
                return
            }

            viewModel.expandedFolderIDs.insert(node.item.id)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard isReloading == false,
                  let node = notification.userInfo?["NSObject"] as? OutlineNode else {
                return
            }

            viewModel.expandedFolderIDs.remove(node.item.id)
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            pasteboardWriterForItem item: Any
        ) -> NSPasteboardWriting? {
            guard let node = item as? OutlineNode else {
                return nil
            }

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(node.item.id.uuidString, forType: .string)
            viewModel.beginDragging(itemID: node.item.id)
            return pasteboardItem
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            validateDrop info: any NSDraggingInfo,
            proposedItem item: Any?,
            proposedChildIndex index: Int
        ) -> NSDragOperation {
            let destination = dropDestination(proposedItem: item, proposedChildIndex: index)

            return viewModel.canAcceptDrop(
                destinationParentID: destination.parentID,
                insertionIndex: destination.index
            ) ? .move : []
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            acceptDrop info: any NSDraggingInfo,
            item: Any?,
            childIndex index: Int
        ) -> Bool {
            let destination = dropDestination(proposedItem: item, proposedChildIndex: index)
            let didDrop = viewModel.performDrop(
                destinationParentID: destination.parentID,
                insertionIndex: destination.index
            )
            reload()
            return didDrop
        }

        private func dropDestination(proposedItem item: Any?, proposedChildIndex index: Int) -> (parentID: UUID?, index: Int) {
            if let node = item as? OutlineNode {
                if index == NSOutlineViewDropOnItemIndex {
                    return (node.item.id, node.item.children?.count ?? 0)
                }

                return (node.item.id, max(0, index))
            }

            return (nil, index == NSOutlineViewDropOnItemIndex ? rootNodes.count : max(0, index))
        }

        private func rebuildNodes() {
            nodesByID = [:]
            rootNodes = viewModel.store.prompts.map { makeNode(from: $0, parent: nil) }
        }

        private func makeNode(from item: PromptItem, parent: OutlineNode?) -> OutlineNode {
            let node = OutlineNode(item: item, parent: parent)
            nodesByID[item.id] = node
            node.children = item.children?.map { makeNode(from: $0, parent: node) } ?? []
            return node
        }

        private func restoreExpansion(in outlineView: NSOutlineView) {
            for folderID in viewModel.expandedFolderIDs {
                if let node = nodesByID[folderID] {
                    outlineView.expandItem(node, expandChildren: false)
                }
            }
        }

        private func restoreSelection(in outlineView: NSOutlineView) {
            guard let selectedItemID = viewModel.selectedItemID,
                  let selectedNode = nodesByID[selectedItemID] else {
                return
            }

            revealAncestors(of: selectedNode, in: outlineView)
            let row = outlineView.row(forItem: selectedNode)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outlineView.scrollRowToVisible(row)
            }
        }

        private func revealAncestors(of node: OutlineNode, in outlineView: NSOutlineView) {
            var parent = node.parent
            while let current = parent {
                outlineView.expandItem(current, expandChildren: false)
                parent = current.parent
            }
        }

        private func node(for item: Any?) -> OutlineNode? {
            item as? OutlineNode
        }
    }
}

private final class OutlineNode: NSObject {
    let item: PromptItem
    weak var parent: OutlineNode?
    var children: [OutlineNode] = []

    init(item: PromptItem, parent: OutlineNode?) {
        self.item = item
        self.parent = parent
    }
}

/// Modern-dark color constants for the AppKit outline view (mirrors Theme.swift).
private enum ThemeColors {
    static let sidebarBackground = NSColor(srgbRed: 0x22 / 255, green: 0x22 / 255, blue: 0x28 / 255, alpha: 1)
    static let accent = NSColor(srgbRed: 0x6e / 255, green: 0x8e / 255, blue: 0xfb / 255, alpha: 1)
    static let accent2 = NSColor(srgbRed: 0xa7 / 255, green: 0x77 / 255, blue: 0xe3 / 255, alpha: 1)
    static let inkSecondary = NSColor(srgbRed: 0xb7 / 255, green: 0xb7 / 255, blue: 0xc2 / 255, alpha: 1)
}

/// Custom row view that paints the blue -> purple accent gradient for the selected row.
private final class PromptOutlineRowView: NSTableRowView {
    var isSelectedRow = false

    override var isOpaque: Bool { false }

    override func drawSelection(in dirtyRect: NSRect) {
        // Selection is driven by `isSelectedRow`, not the table's own selection state.
    }

    override func draw(_ dirtyRect: NSRect) {
        guard isSelectedRow else { return }

        let rect = bounds.insetBy(dx: 4, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        let gradient = NSGradient(colors: [ThemeColors.accent, ThemeColors.accent2])
        gradient?.draw(in: path, angle: 0)
    }
}

private final class PromptOutlineCell: NSTableCellView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let countField = NSTextField(labelWithString: "")
    private let countContainer = NSView()
    private let stackView = NSStackView()

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: PromptItem, isSelected: Bool) {
        iconView.image = NSImage(
            systemSymbolName: item.isFolder ? "folder.fill" : "sparkle",
            accessibilityDescription: item.isFolder ? "Folder" : "Prompt"
        )
        iconView.contentTintColor = isSelected ? .white : ThemeColors.inkSecondary
        iconView.alphaValue = isSelected ? 1.0 : 0.7

        titleField.stringValue = item.title
        titleField.textColor = isSelected ? .white : ThemeColors.inkSecondary

        if item.isFolder, let children = item.children, children.isEmpty == false {
            countField.stringValue = "\(children.count)"
            countField.textColor = isSelected ? .white : ThemeColors.inkSecondary
            countContainer.layer?.backgroundColor = (isSelected
                ? NSColor.white.withAlphaComponent(0.22)
                : NSColor.white.withAlphaComponent(0.08)).cgColor
            countContainer.isHidden = false
        } else {
            countContainer.isHidden = true
        }
    }

    private func setup() {
        wantsLayer = true

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.font = NSFont.systemFont(ofSize: 13)

        countField.font = NSFont.systemFont(ofSize: 11)
        countField.alignment = .center
        countField.translatesAutoresizingMaskIntoConstraints = false

        countContainer.wantsLayer = true
        countContainer.layer?.cornerRadius = 8
        countContainer.setContentHuggingPriority(.required, for: .horizontal)
        countContainer.addSubview(countField)
        NSLayoutConstraint.activate([
            countField.leadingAnchor.constraint(equalTo: countContainer.leadingAnchor, constant: 7),
            countField.trailingAnchor.constraint(equalTo: countContainer.trailingAnchor, constant: -7),
            countField.topAnchor.constraint(equalTo: countContainer.topAnchor, constant: 1),
            countField.bottomAnchor.constraint(equalTo: countContainer.bottomAnchor, constant: -1),
        ])

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleField)
        stackView.addArrangedSubview(countContainer)

        addSubview(stackView)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
