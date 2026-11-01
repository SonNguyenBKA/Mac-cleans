import Foundation

public struct ProcessRow: Identifiable, Hashable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let uid: UInt32
    public let cpu: Double
    public let memoryBytes: Int64
    public let path: String
    public let canKill: Bool

    public var name: String { (path as NSString).lastPathComponent }

    /// Bundle .app ngoài cùng chứa tiến trình (helper của Chrome, VS Code… thuộc về app cha).
    public var appBundlePath: String? {
        guard let r = path.range(of: ".app/") else { return nil }
        return String(path[..<r.lowerBound]) + ".app"
    }

    /// Giải thích ngắn cho các tiến trình hệ thống hay ăn tài nguyên.
    public var explanation: String? {
        switch name {
        case "mds", "mds_stores", "mdworker", "mdworker_shared": "Spotlight đang đánh index, tự hết sau một lúc"
        case "WindowServer": "Vẽ giao diện màn hình"
        case "kernel_task": "Nhân macOS, thường do máy nóng"
        case "syspolicyd": "Kiểm tra chữ ký ứng dụng"
        case "backupd": "Time Machine đang sao lưu"
        case "photoanalysisd": "Photos đang phân tích ảnh"
        case "softwareupdated": "Đang kiểm tra / tải bản cập nhật macOS"
        case "bird", "cloudd": "iCloud đang đồng bộ"
        default: nil
        }
    }

    public var appName: String? {
        appBundlePath.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
    }
}

public enum ProcessMonitor {
    /// Parse output của `ps -Axo pid=,uid=,pcpu=,rss=,comm=` (rss tính bằng KB, comm có thể chứa dấu cách).
    public static func parse(_ output: String, ownUID: UInt32 = getuid(), ownPID: Int32 = getpid()) -> [ProcessRow] {
        output.split(separator: "\n").compactMap { line in
            let f = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard f.count == 5, let pid = Int32(f[0]), let uid = UInt32(f[1]),
                  let cpu = Double(f[2]), let rss = Int64(f[3]) else { return nil }
            let path = String(f[4])
            let canKill = uid == ownUID && pid != ownPID && !path.hasPrefix("/System/")
            return ProcessRow(pid: pid, uid: uid, cpu: cpu, memoryBytes: rss * 1024, path: path, canKill: canKill)
        }
    }

    /// Tiến trình đang chạy nặng ngay lúc này, nặng CPU nhất lên đầu.
    public static func heavy(_ rows: [ProcessRow], cpuAtLeast: Double = 25,
                             memoryAtLeast: Int64 = 1_000_000_000) -> [ProcessRow] {
        rows.filter { $0.cpu >= cpuAtLeast || $0.memoryBytes >= memoryAtLeast }
            .sorted { ($0.cpu, $0.memoryBytes) > ($1.cpu, $1.memoryBytes) }
    }

    public static func snapshot() -> [ProcessRow] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Axo", "pid=,uid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        p.standardOutput = pipe
        guard (try? p.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return parse(String(decoding: data, as: UTF8.self))
    }

    public static func terminate(_ row: ProcessRow, force: Bool, logger: ActionLogger = .default) throws {
        guard row.canKill else { throw POSIXError(.EPERM) }
        if kill(row.pid, force ? SIGKILL : SIGTERM) != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPERM)
        }
        logger.log(force ? "SIGKILL" : "SIGTERM", "\(row.pid) \(row.path)")
    }
}

/// Theo dõi tiến trình ăn CPU vượt ngưỡng liên tục quá `minDuration` giây.
public struct HotProcessTracker: Sendable {
    public let cpuThreshold: Double
    public let minDuration: TimeInterval
    private var since: [Int32: Date] = [:]

    public init(cpuThreshold: Double = 80, minDuration: TimeInterval = 300) {
        self.cpuThreshold = cpuThreshold
        self.minDuration = minDuration
    }

    public mutating func update(_ rows: [ProcessRow], now: Date = Date()) -> [(row: ProcessRow, since: Date)] {
        let busy = rows.filter { $0.cpu >= cpuThreshold }
        since = Dictionary(uniqueKeysWithValues: busy.map { ($0.pid, since[$0.pid] ?? now) })
        return busy.compactMap { row in
            let start = since[row.pid]!
            return now.timeIntervalSince(start) >= minDuration ? (row, start) : nil
        }
    }
}
