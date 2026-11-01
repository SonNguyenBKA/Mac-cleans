import Foundation

public struct CleanResult: Sendable {
    public var cleaned: [CleanItem] = []
    public var trashedURLs: [URL] = []
    public var failures: [(item: CleanItem, reason: String)] = []

    public init() {}

    public var freedBytes: Int64 { cleaned.reduce(0) { $0 + $1.size } }

    public mutating func merge(_ other: CleanResult) {
        cleaned += other.cleaned
        trashedURLs += other.trashedURLs
        failures += other.failures
    }
}

public struct Cleaner: Sendable {
    let logger: ActionLogger

    public init(logger: ActionLogger = .default) {
        self.logger = logger
    }

    /// Dọn các item đã chọn của một group. Mỗi item phải qua PathGuard của group đó.
    /// `permanently`: xoá thẳng thay vì chuyển vào Thùng rác.
    public func clean(_ items: [CleanItem], in group: JunkGroup, permanently: Bool = false) -> CleanResult {
        var result = CleanResult()
        let guard_ = PathGuard(allowedRoots: group.allowedRoots)
        let fm = FileManager.default

        for item in items {
            do {
                if let command = item.command {
                    try run(command)
                    logger.log("RUN", command.joined(separator: " "))
                } else {
                    try guard_.validate(item.url)
                    switch permanently ? .deletePermanently : group.mode {
                    case .trash:
                        var trashed: NSURL?
                        try fm.trashItem(at: item.url, resultingItemURL: &trashed)
                        if let trashed { result.trashedURLs.append(trashed as URL) }
                        logger.log("TRASH", "\(item.url.path) (\(ByteFormat.string(item.size)))")
                    case .deletePermanently:
                        try fm.removeItem(at: item.url)
                        logger.log("DELETE", "\(item.url.path) (\(ByteFormat.string(item.size)))")
                    }
                }
                result.cleaned.append(item)
            } catch {
                logger.log("FAIL", "\(item.url.path): \(error.localizedDescription)")
                result.failures.append((item, error.localizedDescription))
            }
        }
        return result
    }

    private func run(_ command: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: command[0])
        p.arguments = Array(command.dropFirst())
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "MacCleaner", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Lệnh lỗi (exit \(p.terminationStatus))"])
        }
    }
}
