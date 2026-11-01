import XCTest
@testable import MacCleanerCore

final class FanSafetyTests: XCTestCase {
    func testClampKeepsRPMWithinFanRange() {
        XCTAssertEqual(FanSafety.clamp(500, min: 1200, max: 5779), 1200)
        XCTAssertEqual(FanSafety.clamp(9000, min: 1200, max: 5779), 5779)
        XCTAssertEqual(FanSafety.clamp(3000, min: 1200, max: 5779), 3000)
        XCTAssertEqual(FanSafety.clamp(.nan, min: 1200, max: 5779), 1200)
    }

    func testWatchdogExpiresOnlyWhenManualAndSilent() {
        var w = FanSafety.Watchdog(timeout: 15)
        let t0 = Date()
        XCTAssertFalse(w.shouldReset(now: t0))           // chưa có quạt thủ công
        w.manualFans.insert(0)
        w.beat(now: t0)
        XCTAssertFalse(w.shouldReset(now: t0 + 10))
        XCTAssertTrue(w.shouldReset(now: t0 + 16))
        w.beat(now: t0 + 16)
        XCTAssertFalse(w.shouldReset(now: t0 + 20))
        w.manualFans.removeAll()
        XCTAssertFalse(w.shouldReset(now: t0 + 100))
    }

    func testRequirementPinsAppIdentityAndTeam() {
        XCTAssertEqual(FanHelperConstants.clientRequirement,
                       #"anchor apple generic and identifier "com.local.MacCleaner" and certificate leaf[subject.OU] = "B3855LQTCZ""#)
    }
}
