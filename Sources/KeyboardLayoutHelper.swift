import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class KeyboardLayoutHelper: ObservableObject {
    let supportedBackKeyCodes: Set<UInt16> = [10, 50]

    @Published private(set) var backKeyDisplay = "§"

    private var layoutObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        refresh()
        layoutObserver = notificationCenter.addObserver(
            forName: NSTextInputContext.keyboardSelectionDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func isBackKey(_ keyCode: UInt16) -> Bool {
        supportedBackKeyCodes.contains(keyCode)
    }

    func refresh() {
        for keyCode in supportedBackKeyCodes.sorted() {
            if let character = translatedCharacter(for: keyCode), character.isEmpty == false {
                backKeyDisplay = character
                return
            }
        }

        backKeyDisplay = "§"
    }

    private func translatedCharacter(for keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let keyboardLayoutBytes = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        let keyboardLayout = keyboardLayoutBytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )

        guard status == noErr, length > 0 else {
            return nil
        }

        return String(utf16CodeUnits: characters, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
