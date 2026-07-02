import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    var onPromptSelected: ((PromptItem) -> Void)?

    private let panel = PickerPanel(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
        styleMask: [.nonactivatingPanel, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    private let visualEffectView = NSVisualEffectView()
    private let keyboardLayoutHelper: KeyboardLayoutHelper
    private var hostingController: NSHostingController<FloatingPanelView>!
    private var navigationState = PickerNavigationState()
    private var pendingSelectionTask: Task<Void, Never>?
    private var isSearching = false
    private var highlight = 0

    init(keyboardLayoutHelper: KeyboardLayoutHelper = KeyboardLayoutHelper()) {
        self.keyboardLayoutHelper = keyboardLayoutHelper
        super.init()

        hostingController = NSHostingController(
            rootView: FloatingPanelView(
                items: [],
                title: "Prompt Palette",
                highlightedIndex: nil,
                isNested: false,
                isSearching: false,
                searchQuery: "",
                footerText: "tab to search · esc dismiss",
                transitionDirection: .forward,
                onBack: { [weak self] in self?.goBack() },
                onActivateSearch: { [weak self] in self?.activateSearchFromClick() }
            )
        )

        configurePanel()
    }

    var isVisible: Bool { panel.isVisible }

    func show(with prompts: [PromptItem]) {
        pendingSelectionTask?.cancel()
        navigationState.show(rootItems: prompts)
        isSearching = false
        highlight = 0
        guard navigationState.currentItems.isEmpty == false else { return }

        updateView(highlightedIndex: 0, direction: .forward)
        resizePanel(for: navigationState.displayedItems.count)
        positionPanel()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func dismiss() {
        pendingSelectionTask?.cancel()
        pendingSelectionTask = nil
        isSearching = false
        highlight = 0
        panel.orderOut(nil)
    }

    // MARK: - Panel Configuration

    private func configurePanel() {
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.onKeyEvent = { [weak self] event in
            self?.handle(event: event) ?? false
        }
        panel.onResignKey = { [weak self] in
            self?.dismiss()
        }

        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true

        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])

        panel.contentView = visualEffectView
    }

    // MARK: - Key Handling

    private func handle(event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            dismiss()
            return true
        }

        if isSearching {
            return handleSearchKey(event)
        }

        // Arrow navigation + Enter work in accelerator mode too (the "forgot a
        // keybind / just point at it" path), alongside the 1-5 / QWER shortcuts.
        switch event.keyCode {
        case 48: // Tab enters search mode
            enterSearch()
            return true
        case 125: // Arrow down
            moveHighlight(by: 1)
            return true
        case 126: // Arrow up
            moveHighlight(by: -1)
            return true
        case 36, 76: // Return / keypad enter
            activateHighlighted()
            return true
        default:
            break
        }

        if keyboardLayoutHelper.isBackKey(event.keyCode) {
            goBack()
            return true
        }

        guard let index = selectedPromptIndex(for: event) else { return false }
        guard navigationState.currentItems.indices.contains(index) else { return true }

        activate(item: navigationState.currentItems[index], at: index)
        return true
    }

    /// Open a folder or run a prompt, with the brief highlight animation.
    private func activate(item: PromptItem, at displayIndex: Int) {
        if item.isFolder {
            updateView(highlightedIndex: displayIndex, direction: .forward)
            pendingSelectionTask?.cancel()
            pendingSelectionTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard Task.isCancelled == false else { return }
                guard let self else { return }
                _ = self.navigationState.enter(item)
                self.isSearching = false
                self.highlight = 0
                self.renderResting(direction: .forward)
            }
        } else {
            updateView(highlightedIndex: displayIndex, direction: .forward)
            pendingSelectionTask?.cancel()
            if let selectedPrompt = navigationState.enter(item) {
                pendingSelectionTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(180))
                    guard Task.isCancelled == false else { return }
                    self?.onPromptSelected?(selectedPrompt)
                    self?.dismiss()
                }
            }
        }
    }

    // MARK: - Highlight (arrow) navigation

    private func moveHighlight(by delta: Int) {
        let count = navigationState.displayedItems.count
        guard count > 0 else { return }
        highlight = min(max(0, highlight + delta), count - 1)
        updateView(highlightedIndex: highlight, direction: .forward)
    }

    private func activateHighlighted() {
        let items = navigationState.displayedItems
        guard items.indices.contains(highlight) else { return }
        activate(item: items[highlight], at: highlight)
    }

    private func clampHighlight() {
        let count = navigationState.displayedItems.count
        highlight = count > 0 ? min(max(0, highlight), count - 1) : 0
    }

    /// Re-render the resting state (no press animation) with the current highlight.
    private func renderResting(direction: PickerTransitionDirection = .forward) {
        clampHighlight()
        let count = navigationState.displayedItems.count
        updateView(highlightedIndex: count > 0 ? highlight : nil, direction: direction)
        resizePanelAnimated(for: count)
    }

    // MARK: - Search Mode

    /// Activate search from a click on the always-visible search bar.
    private func activateSearchFromClick() {
        guard isSearching == false else { return }
        enterSearch()
    }

    private func enterSearch() {
        pendingSelectionTask?.cancel()
        pendingSelectionTask = nil
        isSearching = true
        highlight = 0
        navigationState.searchQuery = ""
        renderResting(direction: .forward)
    }

    private func exitSearch() {
        isSearching = false
        highlight = 0
        navigationState.searchQuery = ""
        renderResting(direction: .backward)
    }

    private func handleSearchKey(_ event: NSEvent) -> Bool {
        // The back key (§) exits search and returns to accelerator mode.
        if keyboardLayoutHelper.isBackKey(event.keyCode) {
            exitSearch()
            return true
        }

        switch event.keyCode {
        case 48: // Tab — already searching, ignore
            return true
        case 51: // Delete / Backspace — edit the query
            if navigationState.searchQuery.isEmpty == false {
                navigationState.searchQuery.removeLast()
                highlight = 0
                renderResting()
            }
            return true
        case 125: // Arrow down
            moveHighlight(by: 1)
            return true
        case 126: // Arrow up
            moveHighlight(by: -1)
            return true
        case 36, 76: // Return / keypad enter — run highlighted item
            activateHighlighted()
            return true
        default:
            appendSearchCharacters(from: event)
            return true
        }
    }

    private func appendSearchCharacters(from event: NSEvent) {
        let blocked: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.isDisjoint(with: blocked),
              let characters = event.characters,
              characters.isEmpty == false,
              characters.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            return
        }

        navigationState.searchQuery.append(characters)
        highlight = 0
        renderResting()
    }

    private func goBack() {
        pendingSelectionTask?.cancel()
        pendingSelectionTask = nil
        guard navigationState.goBack() else { return }
        highlight = 0
        renderResting(direction: .backward)
    }

    private func selectedPromptIndex(for event: NSEvent) -> Int? {
        // Physical key codes — layout-independent
        // Row 1: 1-5, Row 2: Q-W-E-R (left hand only)
        switch event.keyCode {
        case 18: return 0  // 1
        case 19: return 1  // 2
        case 20: return 2  // 3
        case 21: return 3  // 4
        case 23: return 4  // 5
        case 12: return 5  // Q
        case 13: return 6  // W
        case 14: return 7  // E
        case 15: return 8  // R
        // Numpad
        case 83: return 0
        case 84: return 1
        case 85: return 2
        case 86: return 3
        case 87: return 4
        case 88: return 5
        case 89: return 6
        case 91: return 7
        case 92: return 8
        default: return nil
        }
    }

    // MARK: - View Updates

    private func updateView(highlightedIndex: Int?, direction: PickerTransitionDirection) {
        let backKey = keyboardLayoutHelper.backKeyDisplay
        hostingController.rootView = FloatingPanelView(
            items: navigationState.displayedItems,
            title: navigationState.currentTitle,
            highlightedIndex: highlightedIndex,
            isNested: navigationState.isNested,
            isSearching: isSearching,
            searchQuery: navigationState.searchQuery,
            footerText: navigationState.footerText(backKeyDisplay: backKey, isSearching: isSearching),
            transitionDirection: direction,
            onBack: { [weak self] in self?.goBack() },
            onActivateSearch: { [weak self] in self?.activateSearchFromClick() }
        )
    }

    // MARK: - Panel Sizing & Positioning

    private func resizePanel(for itemCount: Int) {
        panel.setContentSize(NSSize(width: 420, height: panelHeight(for: itemCount)))
    }

    private func resizePanelAnimated(for itemCount: Int) {
        let newSize = NSSize(width: 420, height: panelHeight(for: itemCount))
        let oldFrame = panel.frame
        let newY = oldFrame.origin.y + oldFrame.height - newSize.height
        let newFrame = NSRect(origin: NSPoint(x: oldFrame.origin.x, y: newY), size: newSize)
        panel.animator().setFrame(newFrame, display: true)
    }

    private func panelHeight(for itemCount: Int) -> CGFloat {
        let headerHeight: CGFloat = 56
        let footerHeight: CGFloat = 40
        let dividers: CGFloat = 2
        let rowHeight: CGFloat = 44
        let verticalPadding: CGFloat = 16
        let searchBarHeight: CGFloat = 54 // search bar is always visible

        if itemCount == 0 {
            return headerHeight + footerHeight + dividers + searchBarHeight + 100
        }

        return headerHeight + footerHeight + dividers + searchBarHeight + verticalPadding + (CGFloat(itemCount) * rowHeight)
    }

    private func positionPanel() {
        let screen = screenContainingMouse() ?? NSScreen.main
        guard let screen else { return }
        let frame = panel.frame
        let x = screen.frame.midX - (frame.width / 2)
        let y = screen.frame.midY - (frame.height / 2)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
    }
}

// MARK: - PickerPanel

private final class PickerPanel: NSPanel {
    var onKeyEvent: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true { return }
        super.keyDown(with: event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
