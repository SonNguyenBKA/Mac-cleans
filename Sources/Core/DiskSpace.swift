import Foundation

public struct DiskSpace: Sendable, Equatable {
    public let total: Int64
    /// Dung lượng trống, tính cả phần "purgeable" macOS có thể giải phóng.
    public let available: Int64

    public init(total: Int64, available: Int64) {
        self.total = total
        self.available = available
    }

    public var used: Int64 { total - available }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    public static func current(for url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskSpace? {
        guard let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = v.volumeTotalCapacity, let available = v.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return DiskSpace(total: Int64(total), available: available)
    }
}
