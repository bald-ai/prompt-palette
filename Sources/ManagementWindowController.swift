import AppKit
import SwiftUI

@MainActor
final class ManagementWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: ManagementViewModel
    private var keyDownMonitor: Any?

    init(store: PromptStore, usageStatsStore: UsageStatsStore) {
        self.viewModel = ManagementViewModel(store: store)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Prompt Palette"
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 720, height: 480)
        window.contentView = NSHostingView(
            rootView: ManagementView(
                store: store,
                viewModel: viewModel,
                usageStatsStore: usageStatsStore,
                onExit: { [weak window] in
                    window?.close()
                }
            )
        )

        super.init(window: window)
        window.delegate = self
        installKeyDownMonitor(for: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            if let keyDownMonitor {
                NSEvent.removeMonitor(keyDownMonitor)
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        viewModel.handleWindowClosing()
    }

    private func installKeyDownMonitor(for window: NSWindow) {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let self,
                  event.window === window else {
                return event
            }

            let blockedModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
                return event
            }

            if event.keyCode == AppShortcuts.Key.escape {
                window?.close()
                return nil
            }

            guard self.shouldHandleNavigationKey(in: window) else {
                return event
            }

            switch event.keyCode {
            case AppShortcuts.Key.returnKey, AppShortcuts.Key.keypadEnter:
                self.viewModel.toggleSelectedFolderExpansion()
                return nil
            case AppShortcuts.Key.arrowDown:
                self.viewModel.moveSelectionDown()
                return nil
            case AppShortcuts.Key.arrowUp:
                self.viewModel.moveSelectionUp()
                return nil
            default:
                return event
            }
        }
    }

    private func shouldHandleNavigationKey(in window: NSWindow?) -> Bool {
        guard let firstResponder = window?.firstResponder else {
            return true
        }

        return firstResponder is NSTextView == false
    }
}
