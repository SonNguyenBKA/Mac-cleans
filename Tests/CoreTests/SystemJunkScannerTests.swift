import XCTest
@testable import MacCleanerCore

final class SystemJunkScannerTests: XCTestCase {
    private func makeScanner(_ t: TempDir) -> SystemJunkScanner {
        SystemJunkScanner(home: t.url, tmpDir: t.url.appendingPathComponent("tmp"),
                          excludedCacheNames: ["CocoaPods"])
    }

    private func group(_ groups: [JunkGroup], _ id: String) throws -> JunkGroup {
        try XCTUnwrap(groups.first { $0.id == id })
    }

    func testListsCachesPerAppExcludingDevCaches() throws {
        let t = TempDir()
        t.file("Library/Caches/com.example.app/data.bin", bytes: 8000)
        t.file("Library/Caches/CocoaPods/pods.bin", bytes: 8000)
        let caches = try group(makeScanner(t).scan(), "caches")
        XCTAssertEqual(caches.items.map(\.name), ["com.example.app"])
        XCTAssertGreaterThanOrEqual(caches.totalSize, 8000)
        XCTAssertEqual(caches.mode, .trash)
    }

    func testListsLogs() throws {
        let t = TempDir()
        t.file("Library/Logs/app.log", bytes: 5000)
        t.file("Library/Logs/MacCleaner/actions.log", bytes: 5000)
        let logs = try group(makeScanner(t).scan(), "logs")
        XCTAssertEqual(logs.items.map(\.name), ["app.log"])
    }

    func testTempOnlyOlderThanThreeDaysAndNotMetro() throws {
        let t = TempDir()
        t.file("tmp/old.txt", ageDays: 5)
        t.file("tmp/new.txt", ageDays: 1)
        t.dir("tmp/metro-cache", ageDays: 10)
        let temp = try group(makeScanner(t).scan(), "temp")
        XCTAssertEqual(temp.items.map(\.name), ["old.txt"])
    }

    func testTrashIsPermanentAndNotSelectedByDefault() throws {
        let t = TempDir()
        t.file(".Trash/junk.zip", bytes: 4000)
        let trash = try group(makeScanner(t).scan(), "trash")
        XCTAssertEqual(trash.items.map(\.name), ["junk.zip"])
        XCTAssertEqual(trash.mode, .deletePermanently)
        XCTAssertFalse(trash.selectedByDefault)
    }

    func testMissingFoldersGiveEmptyGroupsWithoutCrash() {
        let t = TempDir()
        let groups = makeScanner(t).scan()
        XCTAssertEqual(groups.map(\.id), ["caches", "logs", "temp", "trash"])
        XCTAssertTrue(groups.allSatisfy { $0.items.isEmpty })
    }
}
