import Foundation

enum ScanSupport {
    static let fullDiskAccessNote = "Không đọc được thư mục này. Cấp Full Disk Access cho Mac Cleaner trong System Settings › Privacy & Security."

    /// Các mục con không ẩn của thư mục. Thư mục không tồn tại → []. Không có quyền → throw.
    static func children(of dir: URL) throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        } catch let e as NSError where e.domain == NSCocoaErrorDomain && e.code == NSFileReadNoSuchFileError {
            return []
        }
    }

    static func modificationDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    static func daysAgo(_ date: Date, now: Date) -> Int {
        Int(now.timeIntervalSince(date) / 86400)
    }

    /// Tạo item cho từng mục con (bỏ mục 0 byte); trả kèm note nếu không đọc được.
    static func items(in dir: URL, where include: (URL) -> Bool = { _ in true },
                      detail: (URL) -> String? = { _ in nil }) -> (items: [CleanItem], note: String?) {
        do {
            let items = try children(of: dir).filter(include).compactMap { url -> CleanItem? in
                let size = SizeCalculator.allocatedSize(of: url)
                return size > 0 ? CleanItem(url: url, size: size, detail: detail(url)) : nil
            }
            return (items, nil)
        } catch {
            return ([], fullDiskAccessNote)
        }
    }
}
