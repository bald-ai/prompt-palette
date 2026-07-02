import XCTest
@testable import PromptPalette

final class PreferencesStoreTests: XCTestCase {
    func testLoadMissingFileReturnsDefaultHotkey() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)

        XCTAssertEqual(store.load(), .default)
    }

    func testLoadValidJSONReturnsConfiguredHotkey() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("""
        {
          "hotkeyKeyCode" : 18,
          "hotkeyModifiers" : [
            "command",
            "shift"
          ]
        }
        """.utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(
            store.load(),
            HotKeyPreferences(keyCode: 18, modifiers: [.command, .shift])
        )
    }

    func testLoadCorruptJSONReturnsDefaultHotkey() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("not json".utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testUnknownModifierFallsBackToDefault() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("""
        {
          "hotkeyKeyCode" : 18,
          "hotkeyModifiers" : [
            "hyper"
          ]
        }
        """.utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testMissingKeyCodeFallsBackToDefault() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("""
        {
          "hotkeyModifiers" : [
            "command"
          ]
        }
        """.utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testMissingModifiersFallsBackToDefault() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        try Data("""
        {
          "hotkeyKeyCode" : 18
        }
        """.utf8).write(to: store.preferencesFileURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testSaveAndReloadRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        let store = PreferencesStore(directoryURL: directory)
        let preferences = HotKeyPreferences(keyCode: 120, modifiers: [.option, .control])

        try store.save(preferences)

        let reloaded = PreferencesStore(directoryURL: directory)
        XCTAssertEqual(reloaded.load(), preferences)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
