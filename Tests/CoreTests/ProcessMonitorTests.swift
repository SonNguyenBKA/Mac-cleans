import XCTest
@testable import MacCleanerCore

final class ProcessMonitorTests: XCTestCase {
    let sample = """
      123   501  98.6   1552 /Users/me/.nvm/bun/bin/bun.exe
      165    88  43.4 300000 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer
     9112   501   8.0 200000 /Applications/Claude.app/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS/Claude Helper (Renderer)
        1     0   0.1   9000 /sbin/launchd
      777   501   0.0    100 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
    """

    func testParsesRowsIncludingSpacesInPath() throws {
        let rows = ProcessMonitor.parse(sample, ownUID: 501, ownPID: 999)
        XCTAssertEqual(rows.count, 5)
        let claude = try XCTUnwrap(rows.first { $0.pid == 9112 })
        XCTAssertEqual(claude.name, "Claude Helper (Renderer)")
        XCTAssertEqual(claude.cpu, 8.0)
        XCTAssertEqual(claude.memoryBytes, 200_000 * 1024)
        XCTAssertTrue(claude.canKill)
    }

    func testCannotKillRootOtherUsersSystemOrSelf() {
        let rows = ProcessMonitor.parse(sample, ownUID: 501, ownPID: 123)
        XCTAssertFalse(rows.first { $0.pid == 1 }!.canKill)      // root
        XCTAssertFalse(rows.first { $0.pid == 165 }!.canKill)    // uid khác + /System
        XCTAssertFalse(rows.first { $0.pid == 777 }!.canKill)    // /System
        XCTAssertFalse(rows.first { $0.pid == 123 }!.canKill)    // chính app
    }

    func testHotTrackerNeedsSustainedLoad() {
        var tracker = HotProcessTracker(cpuThreshold: 80, minDuration: 300)
        let busy = ProcessMonitor.parse(sample, ownUID: 501, ownPID: 999)
        let calm = busy.filter { $0.pid != 123 }
        let t0 = Date()
        XCTAssertTrue(tracker.update(busy, now: t0).isEmpty)
        XCTAssertTrue(tracker.update(busy, now: t0 + 240).isEmpty)
        XCTAssertEqual(tracker.update(busy, now: t0 + 360).map(\.row.pid), [123])
        XCTAssertTrue(tracker.update(calm, now: t0 + 370).isEmpty)
        XCTAssertTrue(tracker.update(busy, now: t0 + 380).isEmpty) // đếm lại từ đầu
    }

    func testSnapshotReadsRealProcesses() {
        let rows = ProcessMonitor.snapshot()
        XCTAssertTrue(rows.contains { $0.pid == getpid() })
    }
}

final class HeavyProcessTests: XCTestCase {
    func testHeavyByCPUOrMemorySortedByCPU() {
        let rows = ProcessMonitor.parse("""
          1   501  99.0    1000 /bin/busy
          2   501   2.0 3000000 /Applications/Big.app/Contents/MacOS/Big
          3   501  30.0    1000 /bin/medium
          4   501   1.0    1000 /bin/idle
        """, ownUID: 501, ownPID: 999)
        let heavy = ProcessMonitor.heavy(rows, cpuAtLeast: 25, memoryAtLeast: 1_000_000_000)
        XCTAssertEqual(heavy.map(\.pid), [1, 3, 2])
    }

    func testAppNameFromBundlePath() {
        let rows = ProcessMonitor.parse("""
          9   501   8.0 1000 /Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Renderer).app/Contents/MacOS/Code Helper (Renderer)
          8   501   8.0 1000 /usr/local/bin/node
        """, ownUID: 501, ownPID: 999)
        XCTAssertEqual(rows[0].appName, "Visual Studio Code")
        XCTAssertEqual(rows[0].appBundlePath, "/Applications/Visual Studio Code.app")
        XCTAssertNil(rows[1].appName)
        XCTAssertNil(rows[1].explanation)
    }

    func testExplainsCommonSystemProcesses() {
        let rows = ProcessMonitor.parse("  278    88  51.0 1000 /System/Library/Frameworks/CoreServices.framework/Support/mds_stores",
                                        ownUID: 501, ownPID: 999)
        XCTAssertEqual(rows.first?.explanation, "Spotlight đang đánh index, tự hết sau một lúc")
    }
}
