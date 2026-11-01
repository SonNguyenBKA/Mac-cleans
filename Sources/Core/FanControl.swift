import Foundation

/// Nguồn nhiệt độ để điều khiển quạt.
public enum TempSource: Codable, Hashable, Sendable {
    case sensor(String)        // một key SMC cụ thể
    case group(SensorGroup)    // cảm biến nóng nhất của nhóm
    case hottest               // nóng nhất trong CPU + GPU

    public func temperature(in sensors: [SensorReading]) -> Double? {
        switch self {
        case .sensor(let key): sensors.first { $0.key == key }?.value
        case .group(let g): sensors.filter { $0.group == g }.map(\.value).max()
        case .hottest: sensors.filter { $0.group == .cpu || $0.group == .gpu }.map(\.value).max()
        }
    }

    public func title(_ sensors: [SensorReading]) -> String {
        switch self {
        case .sensor(let key): sensors.first { $0.key == key }.map { "\($0.name) (\(key))" } ?? key
        case .group(let g): "\(g.title) nóng nhất"
        case .hottest: "CPU/GPU nóng nhất"
        }
    }
}

/// Một điểm trên đường cong: tới `temp` °C thì quạt chạy `percent` % của khoảng [min, max].
public struct CurvePoint: Codable, Hashable, Sendable {
    public var temp: Double
    public var percent: Double

    public init(temp: Double, percent: Double) {
        self.temp = temp
        self.percent = percent
    }
}

public enum FanRule: Codable, Hashable, Sendable {
    case auto
    case constant(percent: Double)
    case sensor(source: TempSource, start: Double, max: Double)
    case curve(source: TempSource, points: [CurvePoint])
}

public enum FanCurve {
    /// Dưới điểm đầu tiên → nil (để macOS tự quyết); giữa các điểm nội suy tuyến tính; trên điểm cuối giữ mức cuối.
    public static func percent(at temp: Double, points: [CurvePoint]) -> Double? {
        let p = points.sorted { $0.temp < $1.temp }
        guard let first = p.first, temp >= first.temp else { return nil }
        for (a, b) in zip(p, p.dropFirst()) where temp <= b.temp {
            return b.temp == a.temp ? b.percent : a.percent + (b.percent - a.percent) * (temp - a.temp) / (b.temp - a.temp)
        }
        return p.last!.percent
    }
}

public struct FanPreset: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Rule theo thứ tự quạt; quạt nào không có rule riêng dùng rule cuối.
    public var rules: [FanRule]
    public var isBuiltIn: Bool

    public init(id: UUID = UUID(), name: String, rules: [FanRule], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.rules = rules
        self.isBuiltIn = isBuiltIn
    }

    public func rule(for fan: Int) -> FanRule {
        rules.isEmpty ? .auto : rules[min(fan, rules.count - 1)]
    }

    public static let auto = FanPreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Auto",
                                       rules: [.auto], isBuiltIn: true)
    public static let quiet = FanPreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Yên tĩnh",
                                        rules: [.curve(source: .hottest, points: [CurvePoint(temp: 70, percent: 0),
                                                                                  CurvePoint(temp: 85, percent: 40),
                                                                                  CurvePoint(temp: 95, percent: 100)])],
                                        isBuiltIn: true)
    public static let balanced = FanPreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Cân bằng",
                                           rules: [.curve(source: .hottest, points: [CurvePoint(temp: 55, percent: 0),
                                                                                     CurvePoint(temp: 70, percent: 40),
                                                                                     CurvePoint(temp: 85, percent: 100)])],
                                           isBuiltIn: true)
    public static let maxCooling = FanPreset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Mát tối đa",
                                             rules: [.constant(percent: 100)], isBuiltIn: true)
    public static let builtIns = [auto, quiet, balanced, maxCooling]
}

/// Tính RPM mục tiêu cho từng quạt. Kết quả nil = để quạt ở Auto.
public struct FanController: Sendable {
    let hysteresis: Double
    private var usedTemp: [Int: Double] = [:]

    public init(hysteresis: Double = 2) {
        self.hysteresis = hysteresis
    }

    public mutating func targets(fans: [FanInfo], sensors: [SensorReading], preset: FanPreset,
                                 boost: Bool = false) -> [Int: Double?] {
        var out: [Int: Double?] = [:]
        for fan in fans {
            let percent: Double?
            if boost {
                percent = 100
            } else {
                switch preset.rule(for: fan.id) {
                case .auto: percent = nil
                case .constant(let p): percent = p
                case .sensor(let source, let start, let max):
                    percent = curvePercent(fan.id, source, [CurvePoint(temp: start, percent: 0), CurvePoint(temp: max, percent: 100)], sensors)
                case .curve(let source, let points):
                    percent = curvePercent(fan.id, source, points, sensors)
                }
            }
            out.updateValue(percent.map { fan.rpm(percent: $0) }, forKey: fan.id)
        }
        return out
    }

    /// Nhiệt tăng thì theo ngay; giảm ít hơn `hysteresis` thì giữ mức cũ để quạt không lên xuống liên tục.
    private mutating func curvePercent(_ fan: Int, _ source: TempSource, _ points: [CurvePoint],
                                       _ sensors: [SensorReading]) -> Double? {
        guard let t = source.temperature(in: sensors) else { return nil }
        let previous = usedTemp[fan] ?? t
        let used = t >= previous || previous - t > hysteresis ? t : previous
        usedTemp[fan] = used
        return FanCurve.percent(at: used, points: points)
    }
}

public struct PresetStore: Sendable {
    public let fileURL: URL

    public static let `default` = PresetStore(fileURL: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MacCleaner/fan-presets.json"))

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> [FanPreset] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([FanPreset].self, from: data)) ?? []
    }

    public func save(_ presets: [FanPreset]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(presets).write(to: fileURL, options: .atomic)
    }
}

public struct HistorySample: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let cpu: Double
    public let gpu: Double
    public let fanRPM: [Double]

    public init(date: Date, cpu: Double, gpu: Double, fanRPM: [Double]) {
        self.date = date
        self.cpu = cpu
        self.gpu = gpu
        self.fanRPM = fanRPM
    }
}

/// Lịch sử nhiệt độ/RPM, mặc định 300 mẫu × 2s = 10 phút.
public struct TemperatureHistory: Sendable {
    public let capacity: Int
    public private(set) var samples: [HistorySample] = []

    public init(capacity: Int = 300) {
        self.capacity = capacity
    }

    public mutating func append(_ s: HistorySample) {
        samples.append(s)
        if samples.count > capacity { samples.removeFirst(samples.count - capacity) }
    }
}
