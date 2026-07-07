import Carbon.HIToolbox

struct GlobalShortcut {
    let keyCode: UInt32
    let modifiers: [HotKeyModifier]
}

enum AppShortcuts {
    enum Global {
        static let showPalette = GlobalShortcut(keyCode: UInt32(kVK_F1), modifiers: [.command])
        static let openManagement = GlobalShortcut(keyCode: UInt32(kVK_F2), modifiers: [.command])
    }

    enum Key {
        static let tab = UInt16(kVK_Tab)
        static let delete = UInt16(kVK_Delete)
        static let escape = UInt16(kVK_Escape)
        static let returnKey = UInt16(kVK_Return)
        static let keypadEnter = UInt16(kVK_ANSI_KeypadEnter)
        static let arrowDown = UInt16(kVK_DownArrow)
        static let arrowUp = UInt16(kVK_UpArrow)
    }

    static func paletteItemIndex(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_Keypad1):
            return 0
        case UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_Keypad2):
            return 1
        case UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_Keypad3):
            return 2
        case UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_Keypad4):
            return 3
        case UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_Keypad5):
            return 4
        case UInt16(kVK_ANSI_Q), UInt16(kVK_ANSI_Keypad6):
            return 5
        case UInt16(kVK_ANSI_W), UInt16(kVK_ANSI_Keypad7):
            return 6
        case UInt16(kVK_ANSI_E), UInt16(kVK_ANSI_Keypad8):
            return 7
        case UInt16(kVK_ANSI_R), UInt16(kVK_ANSI_Keypad9):
            return 8
        default:
            return nil
        }
    }
}
