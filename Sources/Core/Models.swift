import Foundation

public struct CleanItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let size: Int64
    public let detail: String?
    /// Nếu có: chạy lệnh này thay vì chuyển file vào Thùng rác.
    public let command: [String]?

    public init(url: URL, name: String? = nil, size: Int64, detail: String? = nil, command: [String]? = nil) {
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.detail = detail
        self.command = command
    }
}

public enum CleanMode: Sendable {
    case trash
    case deletePermanently
}

public struct JunkGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let items: [CleanItem]
    /// Chỉ được xoá item nằm bên trong các thư mục này.
    public let allowedRoots: [URL]
    public let mode: CleanMode
    public let selectedByDefault: Bool
    public let note: String?

    public init(id: String, title: String, icon: String, items: [CleanItem], allowedRoots: [URL],
                mode: CleanMode = .trash, selectedByDefault: Bool = true, note: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.items = items.sorted { $0.size > $1.size }
        self.allowedRoots = allowedRoots
        self.mode = mode
        self.selectedByDefault = selectedByDefault
        self.note = note
    }

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}
