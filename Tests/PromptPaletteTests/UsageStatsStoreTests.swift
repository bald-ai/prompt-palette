import XCTest
@testable import PromptPalette

final class UsageStatsStoreTests: XCTestCase {
    func testLoadMissingFileReturnsZeroTotalUsed() throws {
        let directory = try makeTemporaryDirectory()
        let store = UsageStatsStore(directoryURL: directory)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 0)
    }

    func testLoadTotalUsedAllTimeReturnsSavedCount() throws {
        let directory = try makeTemporaryDirectory()
        let store = UsageStatsStore(directoryURL: directory)
        try Data("""
        {
          "totalUsedAllTime" : 12
        }
        """.utf8).write(to: store.statsFileURL)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 12)
    }

    func testLoadCorruptJSONReturnsZeroTotalUsed() throws {
        let directory = try makeTemporaryDirectory()
        let store = UsageStatsStore(directoryURL: directory)
        try Data("not json".utf8).write(to: store.statsFileURL)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 0)
    }

    func testIncrementTotalUsedAllTimePersistsCount() throws {
        let directory = try makeTemporaryDirectory()
        let store = UsageStatsStore(directoryURL: directory)

        try store.incrementTotalUsedAllTime()
        try store.incrementTotalUsedAllTime()

        let reloaded = UsageStatsStore(directoryURL: directory)
        XCTAssertEqual(reloaded.loadTotalUsedAllTime(), 2)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
