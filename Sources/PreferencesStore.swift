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

final class PreferencesStore {
    let directoryURL: URL
    let preferencesFileURL: URL

    init(directoryURL: URL = PromptStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
        self.preferencesFileURL = directoryURL.appendingPathComponent("preferences.json")
    }

    func loadTotalUsedAllTime() -> Int {
        loadFile().totalUsedAllTime ?? 0
    }

    func incrementTotalUsedAllTime() throws {
        var file = loadFile()
        file = PreferencesFile(
            totalUsedAllTime: (file.totalUsedAllTime ?? 0) + 1
        )
        try saveFile(file)
    }

    private func loadFile() -> PreferencesFile {
        guard FileManager.default.fileExists(atPath: preferencesFileURL.path),
              let data = try? Data(contentsOf: preferencesFileURL),
              let file = try? JSONDecoder.promptPaletteDecoder.decode(PreferencesFile.self, from: data) else {
            return PreferencesFile(totalUsedAllTime: nil)
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
    let totalUsedAllTime: Int?

    init(totalUsedAllTime: Int?) {
        self.totalUsedAllTime = totalUsedAllTime
    }
}
