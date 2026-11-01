import Foundation
import MacCleanerCore
import Observation

@Observable @MainActor
final class ProcessesModel {
    enum SortKey: String, CaseIterable { case cpu = "CPU", memory = "RAM" }

    var rows: [ProcessRow] = []
    var hot: [(row: ProcessRow, since: Date)] = []
    var sortKey: SortKey = .cpu
    var error: String?
    private var tracker: HotProcessTracker

    init() {
        // Có thể hạ ngưỡng khi test: open MacCleaner.app --args -hotSeconds 10
        let d = UserDefaults.standard
        tracker = HotProcessTracker(cpuThreshold: d.object(forKey: "hotCPU") as? Double ?? 80,
                                    minDuration: d.object(forKey: "hotSeconds") as? Double ?? 300)
    }

    var thresholdText: String {
        "≥ \(Int(tracker.cpuThreshold))% CPU liên tục ≥ \(Self.duration(tracker.minDuration))"
    }

    var sortedRows: [ProcessRow] {
        let sorted = rows.sorted { sortKey == .cpu ? $0.cpu > $1.cpu : $0.memoryBytes > $1.memoryBytes }
        return Array(sorted.prefix(60))
    }

    /// Tối đa 8 tiến trình đang chạy nặng (CPU ≥ 25% hoặc RAM ≥ 1 GB).
    var heavyRows: [ProcessRow] { Array(ProcessMonitor.heavy(rows).prefix(8)) }

    func hotSince(_ row: ProcessRow) -> Date? {
        hot.first { $0.row.pid == row.pid }?.since
    }

    /// Chạy liên tục khi màn hình Tiến trình (hoặc app) đang mở.
    func monitor() async {
        while !Task.isCancelled {
            let snapshot = await Task.detached { ProcessMonitor.snapshot() }.value
            rows = snapshot
            hot = tracker.update(snapshot)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func terminate(_ row: ProcessRow, force: Bool) {
        do {
            try ProcessMonitor.terminate(row, force: force)
            error = nil
        } catch {
            self.error = "Không dừng được \(row.name): \(error.localizedDescription)"
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        seconds >= 60 ? "\(Int(seconds / 60)) phút" : "\(Int(seconds)) giây"
    }
}
