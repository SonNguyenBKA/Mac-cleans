import SwiftUI

extension SidebarItem {
    /// Cặp màu sáng dùng cho ô icon, nút tròn và nền (nền được phủ tối thêm).
    var colors: [Color] {
        switch self {
        case .overview: [Color(red: 0.62, green: 0.35, blue: 1.0), Color(red: 0.25, green: 0.55, blue: 1.0)]
        case .system: [Color(red: 1.0, green: 0.35, blue: 0.6), Color(red: 0.65, green: 0.3, blue: 0.95)]
        case .dev: [Color(red: 0.2, green: 0.85, blue: 0.55), Color(red: 0.1, green: 0.6, blue: 0.85)]
        case .largeFiles: [Color(red: 1.0, green: 0.62, blue: 0.2), Color(red: 0.95, green: 0.25, blue: 0.35)]
        case .processes: [Color(red: 0.3, green: 0.55, blue: 1.0), Color(red: 0.2, green: 0.85, blue: 0.9)]
        case .fans: [Color(red: 0.25, green: 0.85, blue: 1.0), Color(red: 0.45, green: 0.35, blue: 1.0)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var subtitle: String {
        switch self {
        case .overview: "Quét toàn bộ máy chỉ với một nút bấm"
        case .system: "Dọn cache, log và file tạm mà ứng dụng để lại"
        case .dev: "Lấy lại dung lượng từ các công cụ lập trình"
        case .largeFiles: "Tìm file nặng hoặc đã lâu không mở"
        case .processes: "Theo dõi tiến trình ăn CPU và RAM"
        case .fans: "Điều khiển quạt theo nhiệt độ"
        }
    }

    var features: [String] {
        switch self {
        case .overview: ["Cache, log và file tạm", "Rác build Xcode, Gradle, npm, node_modules", "File lớn & cũ bị bỏ quên"]
        case .system: ["Cache của từng ứng dụng", "Log hệ thống và ứng dụng", "File tạm cũ hơn 3 ngày, Thùng rác"]
        case .dev: ["Xcode DerivedData, Archives, DeviceSupport", "Cache Gradle, CocoaPods, npm, Yarn, Metro",
                    "node_modules & build của project bỏ lâu"]
        case .largeFiles: ["File từ 500 MB trở lên", "File từ 50 MB không mở hơn 180 ngày", "Bạn tự chọn file cần xoá"]
        case .processes: ["Cảnh báo tiến trình ăn CPU liên tục", "Sắp xếp theo CPU hoặc RAM", "Quit / Force Quit ngay trong app"]
        case .fans: ["Auto, RPM cố định, theo cảm biến, đường cong", "Preset tự tạo, Boost", "Tự về Auto khi thoát app"]
        }
    }
}

/// Nền gradient tối toàn cửa sổ, đổi màu theo mục đang chọn.
struct ThemeBackground: View {
    let item: SidebarItem

    var body: some View {
        ZStack {
            item.gradient
            Color.black.opacity(0.5)
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .top, startRadius: 0, endRadius: 600)
        }
        .ignoresSafeArea()
    }
}
