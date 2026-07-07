import AppKit
import SwiftUI

/// Shared visual styling for the app.
enum Theme {
    static let accentNSColor = NSColor(srgbRed: 0x6e / 255, green: 0x8e / 255, blue: 0xfb / 255, alpha: 1)
    static let accent2NSColor = NSColor(srgbRed: 0xa7 / 255, green: 0x77 / 255, blue: 0xe3 / 255, alpha: 1)
    static let greenNSColor = NSColor(srgbRed: 0x34 / 255, green: 0xc7 / 255, blue: 0x59 / 255, alpha: 1)
    static let editorBackgroundNSColor = NSColor(srgbRed: 0x1e / 255, green: 0x1e / 255, blue: 0x22 / 255, alpha: 1)
    static let sidebarBackgroundNSColor = NSColor(srgbRed: 0x22 / 255, green: 0x22 / 255, blue: 0x28 / 255, alpha: 1)
    static let fieldBackgroundNSColor = NSColor(srgbRed: 0x2a / 255, green: 0x2a / 255, blue: 0x31 / 255, alpha: 1)
    static let contentBackgroundNSColor = NSColor(srgbRed: 0x20 / 255, green: 0x20 / 255, blue: 0x27 / 255, alpha: 1)
    static let lineNSColor = NSColor(srgbRed: 0x3a / 255, green: 0x3a / 255, blue: 0x42 / 255, alpha: 1)
    static let inkSecondaryNSColor = NSColor(srgbRed: 0xb7 / 255, green: 0xb7 / 255, blue: 0xc2 / 255, alpha: 1)

    // Accent colors used across selections, key chips and prominent actions.
    static let accent = Color(nsColor: accentNSColor)
    static let accent2 = Color(nsColor: accent2NSColor)
    static let green = Color(nsColor: greenNSColor)

    // Modern-dark management window surfaces.
    static let editorBackground = Color(nsColor: editorBackgroundNSColor)
    static let sidebarBackground = Color(nsColor: sidebarBackgroundNSColor)
    static let fieldBackground = Color(nsColor: fieldBackgroundNSColor)
    static let contentBackground = Color(nsColor: contentBackgroundNSColor)
    static let line = Color(nsColor: lineNSColor)

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
