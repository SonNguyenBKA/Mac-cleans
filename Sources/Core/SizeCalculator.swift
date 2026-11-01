import Foundation

public enum SizeCalculator {
    private static let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey, .isSymbolicLinkKey]

    /// Dung lượng thật trên đĩa, không đi theo symlink. Path không tồn tại → 0.
    public static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return 0 }
        if values.isSymbolicLink == true || values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [],
                                                     errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let file as URL in e {
            if Task.isCancelled { break }
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
