import XCTest
@testable import MacCleanerCore

final class SizeCalculatorTests: XCTestCase {
    func testDirectorySizeSumsFiles() {
        let t = TempDir()
        t.file("a/one.bin", bytes: 100_000)
        t.file("a/sub/two.bin", bytes: 200_000)
        let size = SizeCalculator.allocatedSize(of: t.url.appendingPathComponent("a"))
        // allocated size làm tròn theo block 4 KB
        XCTAssertGreaterThanOrEqual(size, 300_000)
        XCTAssertLessThan(size, 320_000)
    }

    func testSingleFile() {
        let t = TempDir()
        let f = t.file("x.bin", bytes: 50_000)
        XCTAssertGreaterThanOrEqual(SizeCalculator.allocatedSize(of: f), 50_000)
    }

    func testDoesNotFollowSymlinks() throws {
        let t = TempDir()
        t.file("big/data.bin", bytes: 500_000)
        let d = t.dir("small")
        try FileManager.default.createSymbolicLink(at: d.appendingPathComponent("link"),
                                                   withDestinationURL: t.url.appendingPathComponent("big"))
        XCTAssertLessThan(SizeCalculator.allocatedSize(of: d), 100_000)
    }

    func testMissingPathIsZero() {
        XCTAssertEqual(SizeCalculator.allocatedSize(of: URL(fileURLWithPath: "/nope/\(UUID())")), 0)
    }
}
