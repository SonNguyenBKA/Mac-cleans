import XCTest
@testable import MacCleanerCore

final class ByteFormatTests: XCTestCase {
    func testFormatsZero() {
        XCTAssertEqual(ByteFormat.string(0), "0 KB")
    }
}
