import XCTest
@testable import MacCleanerCore

final class LargeFileScannerTests: XCTestCase {
    func testFindsLargeAndOldFiles() throws {
        let t = TempDir()
        t.file("Movies/big.mov", bytes: 2_000_000)
        t.file("Downloads/old.zip", bytes: 600_000, ageDays: 200)
        t.file("Downloads/old-small.txt", bytes: 100, ageDays: 200)
        t.file("Downloads/new.zip", bytes: 600_000)
        t.file("Library/huge.db", bytes: 2_000_000)
        t.file("proj/node_modules/big.bin", bytes: 2_000_000)

        let scanner = LargeFileScanner(root: t.url, minLargeSize: 1_000_000, minOldSize: 500_000, staleDays: 180)
        let groups = scanner.scan()
        let large = try XCTUnwrap(groups.first { $0.id == "large" })
        let old = try XCTUnwrap(groups.first { $0.id == "old" })

        XCTAssertEqual(large.items.map(\.name), ["big.mov"])
        XCTAssertEqual(old.items.map(\.name), ["old.zip"])
        XCTAssertFalse(large.selectedByDefault)
        XCTAssertEqual(large.allowedRoots, [t.url])
    }

    func testReportsProgress() {
        let t = TempDir()
        for i in 0..<5 { t.file("f\(i).txt") }
        var last = 0
        _ = LargeFileScanner(root: t.url).scan { last = $0 }
        XCTAssertEqual(last, 5)
    }
}

final class LargeFileScannerPermissionTests: XCTestCase {
    func testNotesUnreadableFolders() throws {
        let t = TempDir()
        let locked = t.dir("locked")
        t.file("locked/a.txt")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let large = try XCTUnwrap(LargeFileScanner(root: t.url).scan().first { $0.id == "large" })
        XCTAssertNotNil(large.note)
    }
}
