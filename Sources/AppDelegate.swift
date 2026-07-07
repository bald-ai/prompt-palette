import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let promptStore = PromptStore()
    private let preferencesStore = PreferencesStore()
    private let hotKeyService = HotKeyService()
    private let keyboardLayoutHelper = KeyboardLayoutHelper()
    private lazy var floatingPanelController = FloatingPanelController(keyboardLayoutHelper: keyboardLayoutHelper)

    private var managementWindowController: ManagementWindowController?
    private var statusItem: NSStatusItem?
    private var hasShownHotKeyFailureAlert = false
    private var hasShownPromptLoadFailureAlert = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        promptStore.load()
        setupMainMenu()
        setupStatusItem()
        setupManagementWindow()
        setupFloatingPanel()
        showPromptLoadFailureAlertIfNeeded()
        registerHotKeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Prompt Palette", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.badge.plus", accessibilityDescription: "Prompt Palette")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        let manageItem = NSMenuItem(title: "Manage Prompts...", action: #selector(openManagementWindow(_:)), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupManagementWindow() {
        managementWindowController = ManagementWindowController(store: promptStore, preferencesStore: preferencesStore)
    }

    private func setupFloatingPanel() {
        floatingPanelController.onPromptSelected = { [weak self] prompt in
            let fallbackMessage = "There was an issue with this prompt."
            let content = prompt.content ?? fallbackMessage
            NSPasteboard.general.clearContents()
            _ = NSPasteboard.general.setString(content, forType: .string)

            do {
                try self?.promptStore.incrementUseCount(id: prompt.id)
                try self?.preferencesStore.incrementTotalUsedAllTime()
            } catch {
                NSLog("PromptPalette: Failed to increment use count for %@. Error: %@", prompt.id.uuidString, error.localizedDescription)
            }
        }
    }

    private func registerHotKeys() {
        do {
            try hotKeyService.register(keyCode: 122, modifiers: [.command]) { [weak self] in
                self?.handleHotKeyPressed()
            }
            try hotKeyService.register(keyCode: 120, modifiers: [.command]) { [weak self] in
                self?.openManagementWindow(nil)
            }
        } catch {
            showHotKeyRegistrationFailureAlertIfNeeded()
            NSLog("PromptPalette: %@", error.localizedDescription)
        }
    }

    private func handleHotKeyPressed() {
        if promptStore.prompts.isEmpty {
            openManagementWindow(nil)
            return
        }

        floatingPanelController.show(with: promptStore.prompts)
    }

    private func showPromptLoadFailureAlertIfNeeded() {
        guard hasShownPromptLoadFailureAlert == false,
              let loadFailureMessage = promptStore.loadFailureMessage else {
            return
        }

        hasShownPromptLoadFailureAlert = true
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't load saved prompts"
        alert.informativeText = "\(loadFailureMessage)\n\nPrompt Palette opened with an empty list so you can keep using the app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showHotKeyRegistrationFailureAlertIfNeeded() {
        guard hasShownHotKeyFailureAlert == false else {
            return
        }

        hasShownHotKeyFailureAlert = true
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Global shortcut unavailable"
        alert.informativeText = "Prompt Palette could not register its shortcut. It may already be in use by macOS or another app."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func openManagementWindow(_ sender: Any?) {
        guard let window = managementWindowController?.window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        managementWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    @objc
    private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
