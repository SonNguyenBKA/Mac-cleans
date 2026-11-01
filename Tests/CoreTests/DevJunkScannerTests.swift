import XCTest
@testable import MacCleanerCore

final class DevJunkScannerTests: XCTestCase {
    private func scan(_ t: TempDir) -> [JunkGroup] {
        DevJunkScanner(home: t.url, tmpDir: t.url.appendingPathComponent("tmp"),
                       projectRoots: [t.url.appendingPathComponent("Work")], checkSimulators: false).scan()
    }

    private func group(_ groups: [JunkGroup], _ id: String) throws -> JunkGroup {
        try XCTUnwrap(groups.first { $0.id == id })
    }

    func testDerivedDataPerProjectWithReadableName() throws {
        let t = TempDir()
        t.file("Library/Developer/Xcode/DerivedData/GreenFi-abcdefghijklmnop/Build/x.o", bytes: 9000)
        let g = try group(scan(t), "derivedData")
        XCTAssertEqual(g.items.map(\.name), ["GreenFi"])
    }

    func testArchivesOnlyOlderThan30Days() throws {
        let t = TempDir()
        t.file("Library/Developer/Xcode/Archives/2026-01-01/Old.xcarchive/Info.plist")
        t.dir("Library/Developer/Xcode/Archives/2026-01-01/Old.xcarchive", ageDays: 60)
        t.file("Library/Developer/Xcode/Archives/2026-10-30/New.xcarchive/Info.plist")
        let g = try group(scan(t), "archives")
        XCTAssertEqual(g.items.map(\.name), ["Old.xcarchive"])
    }

    func testPackageCachesAndMetro() throws {
        let t = TempDir()
        t.file(".gradle/caches/modules-2/a.jar", bytes: 5000)
        t.file("Library/Caches/CocoaPods/Pods/x", bytes: 5000)
        t.file(".npm/_cacache/index", bytes: 5000)
        t.file("tmp/metro-cache/a", bytes: 5000)
        t.file("tmp/haste-map-abc", bytes: 5000)
        t.file("tmp/other.txt", bytes: 5000)
        XCTAssertEqual(Set(try group(scan(t), "packageCaches").items.map(\.name)),
                       ["Gradle", "CocoaPods", "npm"])
        XCTAssertEqual(Set(try group(scan(t), "metro").items.map(\.name)), ["metro-cache", "haste-map-abc"])
    }

    func testStaleProjectBuildFoldersOnly() throws {
        let t = TempDir()
        t.file("Work/OldApp/node_modules/react/index.js", bytes: 5000)
        t.file("Work/OldApp/android/app/build/out.apk", bytes: 5000)
        t.file("Work/OldApp/package.json", ageDays: 40)
        t.dir("Work/OldApp/android", ageDays: 40)
        t.file("Work/NewApp/node_modules/react/index.js", bytes: 5000)
        t.file("Work/NewApp/package.json", ageDays: 10)
        let g = try group(scan(t), "projects")
        XCTAssertEqual(Set(g.items.map(\.name)), ["OldApp/node_modules", "OldApp/android/app/build"])
        XCTAssertEqual(g.allowedRoots, [t.url.appendingPathComponent("Work")])
    }

    func testDoesNotDescendIntoNodeModulesForProjects() throws {
        let t = TempDir()
        t.file("Work/OldApp/package.json", ageDays: 40)
        t.file("Work/OldApp/node_modules/lib/package.json", ageDays: 40)
        t.file("Work/OldApp/node_modules/lib/node_modules/x/a.js", bytes: 5000)
        let g = try group(scan(t), "projects")
        XCTAssertEqual(g.items.map(\.name), ["OldApp/node_modules"])
    }
}
