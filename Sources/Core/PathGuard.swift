import Foundation

public enum PathGuardError: LocalizedError, Equatable {
    case notFound(String)
    case forbidden(String)
    case outsideAllowedRoots(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let p): "Không tìm thấy: \(p)"
        case .forbidden(let p): "Đường dẫn hệ thống, không được xoá: \(p)"
        case .outsideAllowedRoots(let p): "Nằm ngoài vùng được phép dọn: \(p)"
        }
    }
}

/// Chốt chặn cuối trước khi xoá: chỉ cho phép path nằm hẳn bên trong một allowed root.
public struct PathGuard: Sendable {
    static let forbiddenPrefixes = [
        "/System", "/usr", "/bin", "/sbin", "/Applications", "/Library", "/opt",
        "/private/etc", "/private/var/db", "/Volumes",
    ]

    public let allowedRoots: [URL]

    public init(allowedRoots: [URL]) {
        self.allowedRoots = allowedRoots
    }

    public func validate(_ url: URL) throws {
        let raw = url.path
        let name = (raw as NSString).lastPathComponent
        let parentRaw = (raw as NSString).deletingLastPathComponent
        // Resolve symlink ở thư mục cha (để chặn đi vòng qua link), giữ nguyên bản thân item.
        guard !name.isEmpty, name != ".", name != "..",
              let parent = Self.realPath(parentRaw),
              FileManager.default.fileExists(atPath: raw) || Self.isSymlink(raw)
        else { throw PathGuardError.notFound(raw) }

        let target = parent == "/" ? "/" + name : parent + "/" + name

        let protected = ["/", "/Users", Self.realPath(NSHomeDirectory()) ?? NSHomeDirectory()]
        if protected.contains(target) || Self.forbiddenPrefixes.contains(where: { Self.isInside(target, $0, orEqual: true) }) {
            throw PathGuardError.forbidden(target)
        }

        let roots = allowedRoots.compactMap { Self.realPath($0.path) }
        guard roots.contains(where: { Self.isInside(target, $0, orEqual: false) }) else {
            throw PathGuardError.outsideAllowedRoots(target)
        }
    }

    static func isInside(_ path: String, _ root: String, orEqual: Bool) -> Bool {
        if path == root { return orEqual }
        return path.hasPrefix(root == "/" ? "/" : root + "/")
    }

    static func realPath(_ path: String) -> String? {
        guard let r = realpath(path, nil) else { return nil }
        defer { free(r) }
        return String(cString: r)
    }

    static func isSymlink(_ path: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }
}
