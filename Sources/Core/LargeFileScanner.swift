import Foundation

public struct LargeFileScanner: Sendable {
    static let skippedDirs: Set<String> = ["node_modules", "Pods", "DerivedData", ".git"]

    let root: URL
    let minLargeSize: Int64
    let minOldSize: Int64
    let staleDays: Int
    let now: Date

    public init(root: URL, minLargeSize: Int64 = 500_000_000, minOldSize: Int64 = 50_000_000,
                staleDays: Int = 180, now: Date = Date()) {
        self.root = root
        self.minLargeSize = minLargeSize
        self.minOldSize = minOldSize
        self.staleDays = staleDays
        self.now = now
    }

    /// `progress` nhận số file đã quét. Dừng sớm khi Task bị huỷ.
    public func scan(progress: (Int) -> Void = { _ in }) -> [JunkGroup] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey,
                                      .contentAccessDateKey, .contentModificationDateKey]
        let cutoff = now.addingTimeInterval(-Double(staleDays) * 86400)
        let homeLibrary = root.appendingPathComponent("Library").standardizedFileURL.path
        var large: [CleanItem] = []
        var old: [CleanItem] = []
        var count = 0
        final class Flag: @unchecked Sendable { var value = false }
        let unreadable = Flag()

        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                               options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                               errorHandler: { _, _ in unreadable.value = true; return true })
        while let url = e?.nextObject() as? URL {
            if Task.isCancelled { break }
            if Self.skippedDirs.contains(url.lastPathComponent) || url.standardizedFileURL.path == homeLibrary {
                e?.skipDescendants()
                continue
            }
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            count += 1
            if count % 500 == 0 { progress(count) }

            let size = Int64(v.totalFileAllocatedSize ?? 0)
            let lastUsed = [v.contentAccessDate, v.contentModificationDate].compactMap { $0 }.max() ?? now
            let days = ScanSupport.daysAgo(lastUsed, now: now)
            let detail = "\(url.deletingLastPathComponent().path.replacingOccurrences(of: root.path, with: "~")) · \(days) ngày chưa mở"
            if size >= minLargeSize {
                large.append(CleanItem(url: url, size: size, detail: detail))
            } else if size >= minOldSize && lastUsed < cutoff {
                old.append(CleanItem(url: url, size: size, detail: detail))
            }
        }
        progress(count)
        let note = unreadable.value ? "Có thư mục không đọc được nên bị bỏ qua. " + ScanSupport.fullDiskAccessNote : nil

        return [
            JunkGroup(id: "large", title: "File lớn (≥ \(ByteFormat.string(minLargeSize)))", icon: "doc.fill",
                      items: large, allowedRoots: [root], selectedByDefault: false, note: note),
            JunkGroup(id: "old", title: "File cũ (> \(staleDays) ngày chưa mở, ≥ \(ByteFormat.string(minOldSize)))",
                      icon: "clock.arrow.circlepath", items: old, allowedRoots: [root], selectedByDefault: false),
        ]
    }
}
