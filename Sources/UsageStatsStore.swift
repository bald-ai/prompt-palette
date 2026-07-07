import Foundation

final class UsageStatsStore {
    let directoryURL: URL
    let statsFileURL: URL

    init(directoryURL: URL = PromptStore.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
        // Keep the old filename so existing all-time usage counts survive this rename.
        self.statsFileURL = directoryURL.appendingPathComponent("preferences.json")
    }

    func loadTotalUsedAllTime() -> Int {
        loadFile().totalUsedAllTime ?? 0
    }

    func incrementTotalUsedAllTime() throws {
        var file = loadFile()
        file = UsageStatsFile(
            totalUsedAllTime: (file.totalUsedAllTime ?? 0) + 1
        )
        try saveFile(file)
    }

    private func loadFile() -> UsageStatsFile {
        guard FileManager.default.fileExists(atPath: statsFileURL.path),
              let data = try? Data(contentsOf: statsFileURL),
              let file = try? JSONDecoder.promptPaletteDecoder.decode(UsageStatsFile.self, from: data) else {
            return UsageStatsFile(totalUsedAllTime: nil)
        }
        return file
    }

    private func saveFile(_ file: UsageStatsFile) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.promptPaletteEncoder.encode(file)
        try data.write(to: statsFileURL, options: .atomic)
    }
}

private struct UsageStatsFile: Codable {
    let totalUsedAllTime: Int?

    init(totalUsedAllTime: Int?) {
        self.totalUsedAllTime = totalUsedAllTime
    }
}
