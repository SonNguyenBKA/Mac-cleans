import Foundation

public struct FanInfo: Identifiable, Hashable, Sendable {
    public let id: Int
    public let actual: Double
    public let min: Double
    public let max: Double
    public let target: Double
    public let isManual: Bool

    public init(id: Int, actual: Double, min: Double, max: Double, target: Double, isManual: Bool) {
        self.id = id
        self.actual = actual
        self.min = min
        self.max = max
        self.target = target
        self.isManual = isManual
    }

    /// RPM cho mức `percent` (0–100) trong khoảng [min, max].
    public func rpm(percent: Double) -> Double { min + (max - min) * Swift.min(100, Swift.max(0, percent)) / 100 }
}

public enum SensorGroup: String, CaseIterable, Codable, Sendable {
    case cpu, gpu, memory, battery, ssd, wireless, power, enclosure, other

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Bộ nhớ"
        case .battery: "Pin"
        case .ssd: "SSD"
        case .wireless: "Wi-Fi"
        case .power: "Nguồn"
        case .enclosure: "Thân máy"
        case .other: "Khác"
        }
    }
}

public struct SensorReading: Identifiable, Hashable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let group: SensorGroup
    public let value: Double
}

public enum SensorCatalog {
    static let prefixes: [(String, SensorGroup)] = [
        ("Tp", .cpu), ("Te", .cpu), ("TC", .cpu), ("Tg", .gpu), ("TG", .gpu), ("Tm", .memory), ("TM", .memory),
        ("TB", .battery), ("TH", .ssd), ("TN", .ssd), ("TW", .wireless), ("TV", .power), ("TP", .power),
        ("Ts", .enclosure), ("TA", .enclosure), ("Ta", .enclosure), ("Tf", .enclosure),
    ]

    public static func group(for key: String) -> SensorGroup? {
        guard key.count == 4, key.hasPrefix("T") else { return nil }
        return prefixes.first { key.hasPrefix($0.0) }?.1 ?? .other
    }

    /// Bỏ giá trị vô lý, đánh số theo nhóm ("CPU 1", "CPU 2"…) theo thứ tự key.
    public static func name(_ readings: [(key: String, value: Double)]) -> [SensorReading] {
        var counters: [SensorGroup: Int] = [:]
        return readings
            .filter { $0.value > 1 && $0.value < 130 }
            .compactMap { r in group(for: r.key).map { (r, $0) } }
            .sorted { ($0.1.rawValue, $0.0.key) < ($1.1.rawValue, $1.0.key) }
            .sorted { SensorGroup.allCases.firstIndex(of: $0.1)! < SensorGroup.allCases.firstIndex(of: $1.1)! }
            .map { r, g in
                counters[g, default: 0] += 1
                return SensorReading(key: r.key, name: "\(g.title) \(counters[g]!)", group: g, value: r.value)
            }
    }
}

/// Đọc quạt và cảm biến nhiệt từ SMC (không cần quyền root).
public final class HardwareMonitor: @unchecked Sendable {
    let smc: SMC
    private lazy var sensorKeys: [String] = smc.allKeys().filter { SensorCatalog.group(for: $0) != nil }

    public init(smc: SMC) {
        self.smc = smc
    }

    public func fans() -> [FanInfo] {
        let count = Int(smc.value("FNum") ?? 0)
        return (0..<count).compactMap { i in
            guard let actual = smc.value("F\(i)Ac"), let min = smc.value("F\(i)Mn"), let max = smc.value("F\(i)Mx") else { return nil }
            return FanInfo(id: i, actual: actual, min: min, max: max, target: smc.value("F\(i)Tg") ?? actual,
                           isManual: (smc.value("F\(i)Md") ?? 0) == 1)
        }
    }

    public func sensors() -> [SensorReading] {
        SensorCatalog.name(sensorKeys.compactMap { key in
            guard let (type, bytes) = try? smc.read(key), type == "flt " || type == "sp78",
                  let v = SMC.decode(type: type, bytes: bytes) else { return nil }
            return (key, v)
        })
    }
}
