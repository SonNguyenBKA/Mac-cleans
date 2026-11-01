import Foundation
import MacCleanerCore
import Observation

@Observable @MainActor
final class AppModel {
    let system = JunkSection(title: "Rác hệ thống") { _, _ in SystemJunkScanner().scan() }

    let dev = JunkSection(title: "Rác dev", rootKey: "devProjectRoot",
                          defaultRoot: URL(fileURLWithPath: "/Users/Work")) { root, _ in
        DevJunkScanner(projectRoots: root.map { [$0] } ?? []).scan()
    }

    let largeFiles = JunkSection(title: "File lớn & cũ", rootKey: "largeFilesRoot",
                                 defaultRoot: FileManager.default.homeDirectoryForCurrentUser) { root, progress in
        guard let root else { return [] }
        return LargeFileScanner(root: root).scan(progress: progress)
    }

    let processes = ProcessesModel()
    let fans = FanModel()

    var junkSections: [JunkSection] { [system, dev, largeFiles] }

    func smartScan() async {
        async let a: Void = system.scan()
        async let b: Void = dev.scan()
        async let c: Void = largeFiles.scan()
        _ = await (a, b, c)
    }

    func cancelAll() {
        for section in junkSections where section.isScanning { section.cancelScan() }
    }
}
