import XCTest
@testable import MacCleanerCore

final class PathGuardTests: XCTestCase {
    func testAllowsItemInsideRoot() throws {
        let t = TempDir()
        let root = t.dir("Caches")
        let item = t.file("Caches/app/data.bin")
        let guard_ = PathGuard(allowedRoots: [root])
        XCTAssertNoThrow(try guard_.validate(item))
        XCTAssertNoThrow(try guard_.validate(item.deletingLastPathComponent()))
    }

    func testRejectsRootItself() {
        let t = TempDir()
        let root = t.dir("Caches")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(root))
    }

    func testRejectsOutsideRoot() {
        let t = TempDir()
        let root = t.dir("Caches")
        let other = t.file("Documents/important.txt")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(other))
    }

    func testRejectsSiblingWithSamePrefix() {
        let t = TempDir()
        let root = t.dir("Caches")
        let sibling = t.file("CachesBackup/x.txt")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(sibling))
    }

    func testRejectsDotDotEscape() {
        let t = TempDir()
        let root = t.dir("Caches")
        t.file("Documents/important.txt")
        let escape = root.appendingPathComponent("../Documents/important.txt")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(escape))
    }

    func testRejectsPathThroughSymlinkedParentPointingOutside() throws {
        let t = TempDir()
        let root = t.dir("Caches")
        let outside = t.dir("Documents")
        t.file("Documents/important.txt")
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: outside)
        let viaLink = root.appendingPathComponent("link/important.txt")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(viaLink))
    }

    func testAllowsSymlinkItselfInsideRoot() throws {
        // Chuyển symlink vào Thùng rác chỉ di chuyển link, không đụng đích.
        let t = TempDir()
        let root = t.dir("Caches")
        let outside = t.dir("Documents")
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertNoThrow(try PathGuard(allowedRoots: [root]).validate(link))
    }

    func testRejectsSystemPathsEvenIfRootAllowsThem() {
        let guard_ = PathGuard(allowedRoots: [URL(fileURLWithPath: "/")])
        XCTAssertThrowsError(try guard_.validate(URL(fileURLWithPath: "/System/Library")))
        XCTAssertThrowsError(try guard_.validate(URL(fileURLWithPath: "/usr/bin")))
        XCTAssertThrowsError(try guard_.validate(URL(fileURLWithPath: "/Applications/Safari.app")))
    }

    func testRejectsHomeDirectoryItself() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let guard_ = PathGuard(allowedRoots: [home.deletingLastPathComponent()])
        XCTAssertThrowsError(try guard_.validate(home))
    }

    func testRejectsNonexistentPath() {
        let t = TempDir()
        let root = t.dir("Caches")
        XCTAssertThrowsError(try PathGuard(allowedRoots: [root]).validate(root.appendingPathComponent("nope")))
    }
}
