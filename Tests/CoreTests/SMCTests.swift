import XCTest
@testable import MacCleanerCore

final class SMCTests: XCTestCase {
    func testParamStructMatchesKernelLayout() {
        XCTAssertEqual(MemoryLayout<SMCParam>.size, 80)
        XCTAssertEqual(MemoryLayout<SMCParam>.offset(of: \SMCParam.keyInfo), 28)
        XCTAssertEqual(MemoryLayout<SMCParam>.offset(of: \SMCParam.result), 40)
        XCTAssertEqual(MemoryLayout<SMCParam>.offset(of: \SMCParam.data32), 44)
        XCTAssertEqual(MemoryLayout<SMCParam>.offset(of: \SMCParam.bytes), 48)
    }

    func testFourCC() {
        XCTAssertEqual(SMC.fourCC("F0Ac"), 0x4630_4163)
        XCTAssertEqual(SMC.string(0x4630_4163), "F0Ac")
    }

    func testDecodeValues() {
        let flt = withUnsafeBytes(of: Float(2334.5)) { Array($0) }
        XCTAssertEqual(SMC.decode(type: "flt ", bytes: flt), 2334.5)
        XCTAssertEqual(SMC.decode(type: "fpe2", bytes: [0x1F, 0x40]), 2000)      // 8000 / 4
        XCTAssertEqual(SMC.decode(type: "sp78", bytes: [0x3C, 0x80]), 60.5)
        XCTAssertEqual(SMC.decode(type: "ui8 ", bytes: [2]), 2)
        XCTAssertEqual(SMC.decode(type: "ui16", bytes: [0x01, 0x00]), 256)
        XCTAssertNil(SMC.decode(type: "ch8*", bytes: [0x41]))
    }

    func testEncodeRoundTrip() {
        XCTAssertEqual(SMC.decode(type: "flt ", bytes: SMC.encode(type: "flt ", value: 3000, size: 4)!), 3000)
        XCTAssertEqual(SMC.decode(type: "fpe2", bytes: SMC.encode(type: "fpe2", value: 2000, size: 2)!), 2000)
        XCTAssertEqual(SMC.encode(type: "ui8 ", value: 1, size: 1), [1])
    }

    func testReadsRealFansWhenAvailable() throws {
        let smc = try SMC()
        let monitor = HardwareMonitor(smc: smc)
        let fans = monitor.fans()
        for fan in fans {
            XCTAssertGreaterThan(fan.max, fan.min)
            XCTAssertGreaterThanOrEqual(fan.actual, 0)
        }
    }
}

final class SensorCatalogTests: XCTestCase {
    func testClassifiesAppleSiliconKeys() {
        XCTAssertEqual(SensorCatalog.group(for: "Tp09"), .cpu)
        XCTAssertEqual(SensorCatalog.group(for: "Tg05"), .gpu)
        XCTAssertEqual(SensorCatalog.group(for: "TB1T"), .battery)
        XCTAssertEqual(SensorCatalog.group(for: "TH0x"), .ssd)
        XCTAssertEqual(SensorCatalog.group(for: "TW0P"), .wireless)
        XCTAssertEqual(SensorCatalog.group(for: "Ts0P"), .enclosure)
        XCTAssertEqual(SensorCatalog.group(for: "TC0P"), .cpu)   // Intel
        XCTAssertNil(SensorCatalog.group(for: "F0Ac"))
    }

    func testNamesAreNumberedPerGroupInKeyOrder() {
        let named = SensorCatalog.name([
            (key: "Tp09", value: 60), (key: "Tp01", value: 62), (key: "Tg05", value: 50), (key: "TB1T", value: 35),
            (key: "Tx99", value: 500),   // giá trị rác → bỏ
        ])
        XCTAssertEqual(named.map(\.name), ["CPU 1", "CPU 2", "GPU 1", "Pin 1"])
        XCTAssertEqual(named.map(\.key), ["Tp01", "Tp09", "Tg05", "TB1T"])
    }
}
