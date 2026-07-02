import SwiftUI

/// Shared visual styling for the app.
enum Theme {
    // Accent colors used across selections, key chips and prominent actions.
    static let accent = Color(red: 0x6e / 255, green: 0x8e / 255, blue: 0xfb / 255)   // #6e8efb
    static let accent2 = Color(red: 0xa7 / 255, green: 0x77 / 255, blue: 0xe3 / 255)  // #a777e3
    static let green = Color(red: 0x34 / 255, green: 0xc7 / 255, blue: 0x59 / 255)    // #34c759

    // Modern-dark management window surfaces.
    static let editorBackground = Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x22 / 255)  // #1e1e22
    static let sidebarBackground = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x28 / 255) // #222228
    static let fieldBackground = Color(red: 0x2a / 255, green: 0x2a / 255, blue: 0x31 / 255)   // #2a2a31
    static let contentBackground = Color(red: 0x20 / 255, green: 0x20 / 255, blue: 0x27 / 255) // #202027
    static let line = Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x42 / 255)              // #3a3a42

    /// Blue -> purple accent gradient used for selections, key chips and prominent buttons.
    static let accentGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft horizontal accent wash used to highlight a hovered/selected row.
    static let rowHighlightGradient = LinearGradient(
        colors: [accent.opacity(0.30), accent2.opacity(0.15)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Gradient applied as a text fill on titles (white -> soft lavender).
    static let titleGradient = LinearGradient(
        colors: [Color.white, Color(red: 0xcb / 255, green: 0xd2 / 255, blue: 1.0)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
