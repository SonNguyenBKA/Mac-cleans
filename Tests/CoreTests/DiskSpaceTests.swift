import XCTest
@testable import MacCleanerCore

final class DiskSpaceTests: XCTestCase {
    func testReadsStartupVolume() throws {
        let space = try XCTUnwrap(DiskSpace.current())
        XCTAssertGreaterThan(space.total, 0)
        XCTAssertGreaterThan(space.available, 0)
        XCTAssertLessThanOrEqual(space.available, space.total)
        XCTAssertEqual(space.used, space.total - space.available)
    }

    func testUsedFraction() {
        XCTAssertEqual(DiskSpace(total: 100, available: 25).usedFraction, 0.75)
        XCTAssertEqual(DiskSpace(total: 0, available: 0).usedFraction, 0)
    }
}
