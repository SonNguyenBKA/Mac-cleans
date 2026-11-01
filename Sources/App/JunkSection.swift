import AppKit
import MacCleanerCore
import Observation

/// Trạng thái của một màn hình quét/dọn (hệ thống, dev, file lớn).
@Observable @MainActor
final class JunkSection {
    typealias Scan = @Sendable (_ root: URL?, _ progress: @escaping @Sendable (Int) -> Void) -> [JunkGroup]

    let title: String
    let rootKey: String?
    var root: URL? {
        didSet { if let rootKey { UserDefaults.standard.set(root?.path, forKey: rootKey) } }
    }
    var groups: [JunkGroup] = []
    var selected: Set<URL> = []
    var isScanning = false
    var isCleaning = false
    var scannedFiles = 0
    var hasScanned = false
    var message: String?

    private let scanner: Scan
    private var currentScan: Task<[JunkGroup], Never>?

    init(title: String, rootKey: String? = nil, defaultRoot: URL? = nil, scanner: @escaping Scan) {
        self.title = title
        self.rootKey = rootKey
        self.scanner = scanner
        if let rootKey {
            root = UserDefaults.standard.string(forKey: rootKey).map { URL(fileURLWithPath: $0) } ?? defaultRoot
        }
    }

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.totalSize } }

    var selectedItems: [(JunkGroup, [CleanItem])] {
        groups.map { g in (g, g.items.filter { selected.contains($0.url) }) }.filter { !$0.1.isEmpty }
    }

    var selectedSize: Int64 { selectedItems.reduce(0) { $0 + $1.1.reduce(0) { $0 + $1.size } } }
    var selectedCount: Int { selectedItems.reduce(0) { $0 + $1.1.count } }
    var selectsPermanentDelete: Bool { selectedItems.contains { $0.0.mode == .deletePermanently } }

    func scan() async {
        currentScan?.cancel()
        isScanning = true
        scannedFiles = 0
        message = nil
        let scanner = scanner, root = root
        let task = Task.detached { () -> [JunkGroup] in
            scanner(root) { n in Task { @MainActor [weak self] in self?.scannedFiles = n } }
        }
        currentScan = task
        let result = await task.value
        guard !task.isCancelled else { return }
        groups = result
        selected = Set(result.filter(\.selectedByDefault).flatMap { $0.items.map(\.url) })
        hasScanned = true
        isScanning = false
    }

    func cancelScan() {
        currentScan?.cancel()
        isScanning = false
    }

    func clean(permanently: Bool = false) async {
        isCleaning = true
        let work = selectedItems
        let result = await Task.detached {
            var total = CleanResult()
            for (group, items) in work { total.merge(Cleaner().clean(items, in: group, permanently: permanently)) }
            return total
        }.value
        var msg = "Đã dọn \(ByteFormat.string(result.freedBytes)) (\(result.cleaned.count) mục)."
        if let f = result.failures.first {
            msg += " \(result.failures.count) mục lỗi, ví dụ \(f.item.name): \(f.reason)"
        }
        isCleaning = false
        await scan()
        message = msg
    }

    // MARK: chọn

    func isSelected(_ group: JunkGroup) -> Bool {
        !group.items.isEmpty && group.items.allSatisfy { selected.contains($0.url) }
    }

    func setSelected(_ group: JunkGroup, _ on: Bool) {
        for item in group.items {
            if on { selected.insert(item.url) } else { selected.remove(item.url) }
        }
    }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = root
        if panel.runModal() == .OK, let url = panel.url { root = url }
    }
}
