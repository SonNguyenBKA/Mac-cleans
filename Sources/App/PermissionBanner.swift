import AppKit
import MacCleanerCore
import SwiftUI

/// Nhắc cấp Full Disk Access một lần thay vì bị hỏi quyền từng thư mục.
struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill").font(.system(size: 28)).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Cấp Full Disk Access một lần để không bị hỏi quyền nữa").fontWeight(.semibold)
                Text("Bật Mac Cleaner trong danh sách (chưa có thì bấm + và chọn /Applications/MacCleaner.app), sau đó mở lại app.")
                    .font(.caption)
                    .opacity(0.75)
            }
            Spacer()
            Button("Mở cài đặt") { NSWorkspace.shared.open(Permissions.fullDiskAccessSettingsURL) }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(14)
        .background(.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.orange.opacity(0.4)))
    }
}
