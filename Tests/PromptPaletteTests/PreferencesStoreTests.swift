import XCTest
@testable import PromptPalette

final class PreferencesStoreTests: XCTestCase {
    func testLoadMissingFileReturnsZeroTotalUsed() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 0)
    }

    func testLoadTotalUsedAllTimeReturnsSavedCount() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("""
        {
          "totalUsedAllTime" : 12
        }
        """.utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 12)
    }

    func testLoadCorruptJSONReturnsZeroTotalUsed() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("not json".utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.loadTotalUsedAllTime(), 0)
    }

    func testIncrementTotalUsedAllTimePersistsCount() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)

        try store.incrementTotalUsedAllTime()
        try store.incrementTotalUsedAllTime()

        let reloaded = PreferencesStore(directoryURL: directory)
        XCTAssertEqual(reloaded.loadTotalUsedAllTime(), 2)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
