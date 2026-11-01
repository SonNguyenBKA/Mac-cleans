import Foundation

public struct SystemJunkScanner: Sendable {
    static let metroPrefixes = ["metro-", "haste-map", "react-native-packager-cache"]

    let home: URL
    let tmpDir: URL
    let now: Date
    let excludedCacheNames: Set<String>

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                tmpDir: URL = URL(fileURLWithPath: NSTemporaryDirectory()),
                now: Date = Date(),
                excludedCacheNames: Set<String> = DevJunkScanner.handledCacheNames) {
        self.home = home
        self.tmpDir = tmpDir
        self.now = now
        self.excludedCacheNames = excludedCacheNames.union([Bundle.main.bundleIdentifier ?? ""])
    }

    public func scan() -> [JunkGroup] {
        let caches = home.appendingPathComponent("Library/Caches")
        let logs = home.appendingPathComponent("Library/Logs")
        let trash = home.appendingPathComponent(".Trash")
        let tempCutoff = now.addingTimeInterval(-3 * 86400)

        let c = ScanSupport.items(in: caches) { !excludedCacheNames.contains($0.lastPathComponent) }
        let l = ScanSupport.items(in: logs) { $0.lastPathComponent != "MacCleaner" }
        let t = ScanSupport.items(in: tmpDir, where: { url in
            let name = url.lastPathComponent
            guard !Self.metroPrefixes.contains(where: name.hasPrefix) else { return false }
            return (ScanSupport.modificationDate(url) ?? now) < tempCutoff
        }, detail: { url in
            ScanSupport.modificationDate(url).map { "\(ScanSupport.daysAgo($0, now: now)) ngày trước" }
        })
        let tr = ScanSupport.items(in: trash)

        return [
            JunkGroup(id: "caches", title: "Cache ứng dụng", icon: "archivebox", items: c.items,
                      allowedRoots: [caches], note: c.note),
            JunkGroup(id: "logs", title: "Log", icon: "doc.text", items: l.items, allowedRoots: [logs], note: l.note),
            JunkGroup(id: "temp", title: "File tạm (> 3 ngày)", icon: "clock", items: t.items,
                      allowedRoots: [tmpDir], note: t.note),
            JunkGroup(id: "trash", title: "Thùng rác", icon: "trash", items: tr.items,
                      allowedRoots: [trash], mode: .deletePermanently, selectedByDefault: false, note: tr.note),
        ]
    }
}
