import Foundation

public struct ActionLogger: Sendable {
    public let fileURL: URL

    public static let `default` = ActionLogger(fileURL: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MacCleaner/actions.log"))

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func log(_ action: String, _ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(action) \(message)\n"
        let fm = FileManager.default
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: fileURL.path) { fm.createFile(atPath: fileURL.path, contents: nil) }
        guard let h = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: Data(line.utf8))
    }
}
