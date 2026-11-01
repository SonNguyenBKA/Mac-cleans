import Foundation

public enum Permissions {
    /// File này chỉ đọc được khi app có Full Disk Access; thử mở không làm macOS hiện hộp thoại hỏi quyền.
    public static var hasFullDiskAccess: Bool {
        let fd = open("/Library/Application Support/com.apple.TCC/TCC.db", O_RDONLY)
        guard fd >= 0 else { return false }
        close(fd)
        return true
    }

    public static let fullDiskAccessSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
}
