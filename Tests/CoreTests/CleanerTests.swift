import XCTest
@testable import MacCleanerCore

final class CleanerTests: XCTestCase {
    func testMovesAllowedItemsToTrashAndLogs() throws {
        let t = TempDir()
        let root = t.dir("Caches")
        let item = t.file("Caches/app/data.bin", bytes: 1000)
        let log = t.url.appendingPathComponent("logs/actions.log")
        let group = JunkGroup(id: "g", title: "G", icon: "", items: [CleanItem(url: item.deletingLastPathComponent(), size: 1000)],
                              allowedRoots: [root])

        let result = Cleaner(logger: ActionLogger(fileURL: log)).clean(group.items, in: group)

        XCTAssertEqual(result.cleaned.count, 1)
        XCTAssertEqual(result.freedBytes, 1000)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
        let trashed = try XCTUnwrap(result.trashedURLs.first)
        XCTAssertTrue(trashed.path.contains("/.Trash/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashed.path))
        try? FileManager.default.removeItem(at: trashed)
        let logText = try String(contentsOf: log, encoding: .utf8)
        XCTAssertTrue(logText.contains("TRASH"))
        XCTAssertTrue(logText.contains(item.deletingLastPathComponent().lastPathComponent))
    }

    func testRefusesItemOutsideAllowedRoots() {
        let t = TempDir()
        let root = t.dir("Caches")
        let outside = t.file("Documents/important.txt")
        let log = t.url.appendingPathComponent("actions.log")
        let group = JunkGroup(id: "g", title: "G", icon: "", items: [CleanItem(url: outside, size: 10)], allowedRoots: [root])

        let result = Cleaner(logger: ActionLogger(fileURL: log)).clean(group.items, in: group)

        XCTAssertTrue(result.cleaned.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testPermanentDeleteRemovesItem() {
        let t = TempDir()
        let root = t.dir("Trash")
        let item = t.file("Trash/old.zip")
        let group = JunkGroup(id: "trash", title: "T", icon: "", items: [CleanItem(url: item, size: 10)],
                              allowedRoots: [root], mode: .deletePermanently)

        let result = Cleaner(logger: ActionLogger(fileURL: t.url.appendingPathComponent("a.log"))).clean(group.items, in: group)

        XCTAssertEqual(result.cleaned.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
    }

    func testRunsCommandItem() {
        let t = TempDir()
        let marker = t.url.appendingPathComponent("ran")
        let item = CleanItem(url: t.url, name: "cmd", size: 5, command: ["/usr/bin/touch", marker.path])
        let group = JunkGroup(id: "c", title: "C", icon: "", items: [item], allowedRoots: [])

        let result = Cleaner(logger: ActionLogger(fileURL: t.url.appendingPathComponent("a.log"))).clean([item], in: group)

        XCTAssertEqual(result.cleaned.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }

    func testFailedCommandIsReported() {
        let t = TempDir()
        let item = CleanItem(url: t.url, name: "cmd", size: 5, command: ["/usr/bin/false"])
        let group = JunkGroup(id: "c", title: "C", icon: "", items: [item], allowedRoots: [])

        let result = Cleaner(logger: ActionLogger(fileURL: t.url.appendingPathComponent("a.log"))).clean([item], in: group)

        XCTAssertTrue(result.cleaned.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
    }
}

final class CleanerPermanentTests: XCTestCase {
    func testPermanentOverrideDeletesInsteadOfTrashing() {
        let t = TempDir()
        let root = t.dir("Caches")
        let item = t.file("Caches/app/data.bin")
        let group = JunkGroup(id: "g", title: "G", icon: "", items: [CleanItem(url: item, size: 10)], allowedRoots: [root])

        let result = Cleaner(logger: ActionLogger(fileURL: t.url.appendingPathComponent("a.log")))
            .clean(group.items, in: group, permanently: true)

        XCTAssertEqual(result.cleaned.count, 1)
        XCTAssertTrue(result.trashedURLs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.path))
    }

    func testPermanentStillRespectsPathGuard() {
        let t = TempDir()
        let root = t.dir("Caches")
        let outside = t.file("Documents/important.txt")
        let group = JunkGroup(id: "g", title: "G", icon: "", items: [CleanItem(url: outside, size: 10)], allowedRoots: [root])

        let result = Cleaner(logger: ActionLogger(fileURL: t.url.appendingPathComponent("a.log")))
            .clean(group.items, in: group, permanently: true)

        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }
}
