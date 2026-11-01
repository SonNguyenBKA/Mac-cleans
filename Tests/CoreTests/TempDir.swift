import Foundation

/// Thư mục tạm cho test, tự xoá khi xong.
final class TempDir {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCleanerTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ path: String, bytes: Int = 10, ageDays: Double = 0) -> URL {
        let f = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(repeating: 1, count: bytes).write(to: f)
        if ageDays > 0 { setAge(f, days: ageDays) }
        return f
    }

    @discardableResult
    func dir(_ path: String, ageDays: Double = 0) -> URL {
        let d = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        if ageDays > 0 { setAge(d, days: ageDays) }
        return d
    }

    /// Đặt cả atime lẫn mtime về `days` ngày trước.
    func setAge(_ u: URL, days: Double) {
        let t = Date().addingTimeInterval(-days * 86400).timeIntervalSince1970
        var times = [timeval(tv_sec: Int(t), tv_usec: 0), timeval(tv_sec: Int(t), tv_usec: 0)]
        precondition(utimes(u.path, &times) == 0)
    }
}
