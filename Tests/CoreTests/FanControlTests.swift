import XCTest
@testable import MacCleanerCore

final class FanCurveTests: XCTestCase {
    let points = [CurvePoint(temp: 50, percent: 0), CurvePoint(temp: 70, percent: 50), CurvePoint(temp: 90, percent: 100)]

    func testBelowFirstPointMeansAuto() {
        XCTAssertNil(FanCurve.percent(at: 45, points: points))
    }

    func testInterpolatesBetweenPoints() {
        XCTAssertEqual(FanCurve.percent(at: 50, points: points), 0)
        XCTAssertEqual(FanCurve.percent(at: 60, points: points), 25)
        XCTAssertEqual(FanCurve.percent(at: 80, points: points), 75)
    }

    func testAboveLastPointHoldsLastPercent() {
        XCTAssertEqual(FanCurve.percent(at: 99, points: points), 100)
    }

    func testUnsortedPointsAreSorted() {
        XCTAssertEqual(FanCurve.percent(at: 60, points: points.reversed()), 25)
    }
}

final class FanControllerTests: XCTestCase {
    let fans = [FanInfo(id: 0, actual: 2000, min: 1200, max: 5200, target: 2000, isManual: false),
                FanInfo(id: 1, actual: 2000, min: 1200, max: 6200, target: 2000, isManual: false)]

    func sensors(cpu: Double, gpu: Double = 40) -> [SensorReading] {
        [SensorReading(key: "Tp01", name: "CPU 1", group: .cpu, value: cpu - 5),
         SensorReading(key: "Tp09", name: "CPU 2", group: .cpu, value: cpu),
         SensorReading(key: "Tg05", name: "GPU 1", group: .gpu, value: gpu)]
    }

    func testAutoPresetGivesNilTargets() {
        var c = FanController()
        XCTAssertEqual(c.targets(fans: fans, sensors: sensors(cpu: 80), preset: .auto), [0: nil, 1: nil])
    }

    func testConstantPercentMapsToEachFanRange() {
        var c = FanController()
        let preset = FanPreset(name: "50%", rules: [.constant(percent: 50)])
        XCTAssertEqual(c.targets(fans: fans, sensors: sensors(cpu: 50), preset: preset), [0: 3200, 1: 3700])
    }

    func testCurveUsesHottestSensorOfGroup() {
        var c = FanController()
        let preset = FanPreset(name: "c", rules: [.curve(source: .group(.cpu), points: [CurvePoint(temp: 60, percent: 0), CurvePoint(temp: 80, percent: 100)])])
        XCTAssertEqual(c.targets(fans: fans, sensors: sensors(cpu: 70), preset: preset)[0]!, 3200)
    }

    func testSensorRuleIsLinearBetweenStartAndMax() {
        var c = FanController()
        let preset = FanPreset(name: "s", rules: [.sensor(source: .sensor("Tg05"), start: 40, max: 80), .auto])
        let t = c.targets(fans: fans, sensors: sensors(cpu: 50, gpu: 60), preset: preset)
        XCTAssertEqual(t[0]!, 3200)
        XCTAssertEqual(t[1]!, nil)
    }

    func testHysteresisIgnoresSmallDrops() {
        var c = FanController(hysteresis: 2)
        let preset = FanPreset(name: "c", rules: [.curve(source: .group(.cpu), points: [CurvePoint(temp: 60, percent: 0), CurvePoint(temp: 80, percent: 100)])])
        let up = c.targets(fans: fans, sensors: sensors(cpu: 70), preset: preset)[0]!
        let smallDrop = c.targets(fans: fans, sensors: sensors(cpu: 69), preset: preset)[0]!
        XCTAssertEqual(up, smallDrop)
        let bigDrop = c.targets(fans: fans, sensors: sensors(cpu: 66), preset: preset)[0]!
        XCTAssertLessThan(bigDrop!, up!)
        let rise = c.targets(fans: fans, sensors: sensors(cpu: 67), preset: preset)[0]!
        XCTAssertGreaterThan(rise!, bigDrop!)
    }

    func testBoostRunsAllFansAtMax() {
        var c = FanController()
        XCTAssertEqual(c.targets(fans: fans, sensors: sensors(cpu: 40), preset: .auto, boost: true), [0: 5200, 1: 6200])
    }

    func testMissingSensorFallsBackToAuto() {
        var c = FanController()
        let preset = FanPreset(name: "s", rules: [.sensor(source: .sensor("XXXX"), start: 40, max: 80)])
        XCTAssertEqual(c.targets(fans: fans, sensors: sensors(cpu: 50), preset: preset)[0]!, nil)
    }

    func testRulesReuseLastRuleForExtraFans() {
        var c = FanController()
        let preset = FanPreset(name: "x", rules: [.constant(percent: 100)])
        XCTAssertEqual(c.targets(fans: fans, sensors: [], preset: preset)[1]!, 6200)
    }
}

final class FanPresetStoreTests: XCTestCase {
    func testBuiltInsExistAndAreReadOnly() {
        let ids = FanPreset.builtIns.map(\.name)
        XCTAssertEqual(ids, ["Auto", "Yên tĩnh", "Cân bằng", "Mát tối đa"])
        XCTAssertTrue(FanPreset.builtIns.allSatisfy(\.isBuiltIn))
    }

    func testSaveAndLoadCustomPresets() throws {
        let t = TempDir()
        let store = PresetStore(fileURL: t.url.appendingPathComponent("presets.json"))
        let custom = FanPreset(name: "Build Xcode", rules: [.curve(source: .hottest, points: [CurvePoint(temp: 55, percent: 20)]),
                                                           .sensor(source: .sensor("Tg05"), start: 45, max: 85)])
        try store.save([custom])
        XCTAssertEqual(store.load(), [custom])
    }

    func testLoadMissingFileGivesEmpty() {
        let t = TempDir()
        XCTAssertEqual(PresetStore(fileURL: t.url.appendingPathComponent("nope.json")).load(), [])
    }
}

final class TemperatureHistoryTests: XCTestCase {
    func testKeepsOnlyCapacitySamples() {
        var h = TemperatureHistory(capacity: 3)
        for i in 0..<5 { h.append(HistorySample(date: Date(timeIntervalSince1970: Double(i)), cpu: Double(i), gpu: 0, fanRPM: [])) }
        XCTAssertEqual(h.samples.map(\.cpu), [2, 3, 4])
    }
}
