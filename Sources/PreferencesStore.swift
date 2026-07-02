import Carbon
import Foundation

enum HotKeyModifier: String, Codable, CaseIterable, Equatable {
    case command
    case option
    case control
    case shift

    var carbonFlag: UInt32 {
        switch self {
        case .command:
            return UInt32(cmdKey)
        case .option:
            return UInt32(optionKey)
        case .control:
            return UInt32(controlKey)
        case .shift:
            return UInt32(shiftKey)
        }
    }
}

struct HotKeyPreferences: Equatable {
    var keyCode: UInt32
    var modifiers: [HotKeyModifier]

    static let `default` = HotKeyPreferences(keyCode: 122, modifiers: [.command])

    var carbonModifiers: UInt32 {
        modifiers.reduce(0) { $0 | $1.carbonFlag }
    }
}

final class PreferencesStore {
    let directoryURL: URL
    let preferencesFileURL: URL

    init(directoryURL: URL = PromptStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
        self.preferencesFileURL = directoryURL.appendingPathComponent("preferences.json")
    }

    func load() -> HotKeyPreferences {
        guard FileManager.default.fileExists(atPath: preferencesFileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: preferencesFileURL)
            let decoded = try JSONDecoder.promptPaletteDecoder.decode(PreferencesFile.self, from: data)
            return try decoded.toPreferences()
        } catch {
            NSLog("PromptPalette: Failed to load preferences from %@. Falling back to defaults. Error: %@", preferencesFileURL.path, String(describing: error))
            return .default
        }
    }

    func save(_ preferences: HotKeyPreferences) throws {
        let current = loadFile()
        let file = PreferencesFile(preferences: preferences, totalUsedAllTime: current.totalUsedAllTime ?? 0)
        try saveFile(file)
    }

    func loadTotalUsedAllTime() -> Int {
        loadFile().totalUsedAllTime ?? 0
    }

    func incrementTotalUsedAllTime() throws {
        var file = loadFile()
        file = PreferencesFile(
            hotkeyKeyCode: file.hotkeyKeyCode,
            hotkeyModifiers: file.hotkeyModifiers,
            totalUsedAllTime: (file.totalUsedAllTime ?? 0) + 1
        )
        try saveFile(file)
    }

    private func loadFile() -> PreferencesFile {
        guard FileManager.default.fileExists(atPath: preferencesFileURL.path),
              let data = try? Data(contentsOf: preferencesFileURL),
              let file = try? JSONDecoder.promptPaletteDecoder.decode(PreferencesFile.self, from: data) else {
            return PreferencesFile(hotkeyKeyCode: nil, hotkeyModifiers: nil, totalUsedAllTime: nil)
        }
        return file
    }

    private func saveFile(_ file: PreferencesFile) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.promptPaletteEncoder.encode(file)
        try data.write(to: preferencesFileURL, options: .atomic)
    }
}

private struct PreferencesFile: Codable {
    let hotkeyKeyCode: UInt32?
    let hotkeyModifiers: [String]?
    let totalUsedAllTime: Int?

    init(hotkeyKeyCode: UInt32?, hotkeyModifiers: [String]?, totalUsedAllTime: Int?) {
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.totalUsedAllTime = totalUsedAllTime
    }

    init(preferences: HotKeyPreferences, totalUsedAllTime: Int) {
        self.hotkeyKeyCode = preferences.keyCode
        self.hotkeyModifiers = preferences.modifiers.map(\.rawValue)
        self.totalUsedAllTime = totalUsedAllTime
    }

    func toPreferences() throws -> HotKeyPreferences {
        guard hotkeyKeyCode != nil || hotkeyModifiers != nil else {
            return .default
        }

        guard let hotkeyKeyCode, let hotkeyModifiers, hotkeyModifiers.isEmpty == false else {
            return .default
        }

        let modifiers = try hotkeyModifiers.map { rawValue in
            guard let modifier = HotKeyModifier(rawValue: rawValue.lowercased()) else {
                throw PreferencesValidationError.unknownModifier(rawValue)
            }

            return modifier
        }

        return HotKeyPreferences(keyCode: hotkeyKeyCode, modifiers: modifiers)
    }
}

private enum PreferencesValidationError: LocalizedError {
    case unknownModifier(String)

    var errorDescription: String? {
        switch self {
        case .unknownModifier(let modifier):
            return "Unknown modifier in preferences: \(modifier)"
        }
    }
}
