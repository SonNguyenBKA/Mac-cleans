# Mac Cleaner

App macOS native (SwiftUI) dùng cá nhân, phong cách giống CleanMyMac: dọn rác, tìm file lớn, theo dõi tiến trình nặng và điều khiển quạt tản nhiệt (kiểu Macs Fan Control, có thêm tính năng Pro).

## Tính năng

| Mục | Nội dung |
|---|---|
| **Tổng quan (Smart Scan)** | Quét song song rác hệ thống, rác dev, file lớn; hiện tổng dung lượng có thể dọn |
| **Rác hệ thống** | `~/Library/Caches`, `~/Library/Logs`, file tạm cũ > 3 ngày, Thùng rác |
| **Rác dev (React Native)** | Xcode DerivedData / Archives / iOS DeviceSupport, simulator hỏng, Gradle, CocoaPods, npm, Yarn, Metro cache, `node_modules` / `android/app/build` / `ios/build` của project không đụng > 30 ngày |
| **File lớn & cũ** | File ≥ 500 MB, hoặc ≥ 50 MB và không mở > 180 ngày; xem trong Finder |
| **Tiến trình** | Bảng CPU/RAM cập nhật mỗi 2s, danh sách tiến trình đang chạy nặng (CPU ≥ 25% hoặc RAM ≥ 1 GB), nút Kết thúc / Buộc dừng |
| **Quạt & nhiệt độ** | Đọc RPM và toàn bộ cảm biến nhiệt; mỗi quạt chọn Auto / RPM cố định / Theo cảm biến / Đường cong kéo thả; preset có sẵn + tự tạo; biểu đồ 10 phút; Boost; menu bar hiện `nhiệt độ · RPM`; mở cùng máy |
| Khác | Thanh dung lượng ổ đĩa còn trống, chuyển vào Thùng rác (mặc định) hoặc xoá vĩnh viễn |

## An toàn

- Không bao giờ tự xoá: luôn Quét → xem danh sách → tích chọn → bấm Dọn → xác nhận.
- Chỉ xoá được đường dẫn nằm trong danh sách thư mục cho phép (`PathGuard`); chặn symlink trỏ ra ngoài và thư mục hệ thống (`/System`, `/usr`…).
- Mọi thao tác dọn / kết thúc tiến trình được ghi vào `~/Library/Logs/MacCleaner/actions.log`.
- Quạt: không bao giờ đặt dưới RPM tối thiểu. Quạt tự về **Auto** khi thoát app, app crash / bị kill, app treo quá 15s (watchdog), helper bị tắt. Khi máy sleep quạt về Auto, wake thì áp lại preset.
- Helper quạt chạy quyền root chỉ nhận lệnh từ đúng app Mac Cleaner ký bằng chứng chỉ của chủ máy.

## Cài đặt

### Từ file `.dmg`
1. Mở `MacCleaner.dmg`, kéo **MacCleaner** vào **Applications**.
2. Lần đầu mở, cấp **Full Disk Access** (System Settings › Privacy & Security › Full Disk Access) để quét được hết thư mục. Chỉ cần cấp một lần.
3. Muốn dùng điều khiển quạt: vào mục **Quạt & nhiệt độ** → bấm cài helper → duyệt trong System Settings › General › Login Items (Allow in the Background).

> File `.dmg` ký bằng chứng chỉ Apple Development, chưa notarize, nên chỉ chạy trơn tru trên máy của chủ chứng chỉ. Trên máy khác cần chuột phải → Open, và phần điều khiển quạt sẽ không hoạt động.

### Build từ mã nguồn

Yêu cầu: macOS 14+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
make build     # build Debug (sinh MacCleaner.xcodeproj từ project.yml)
make run       # build rồi mở app
make test      # chạy test
make install   # build Release và cài vào /Applications
make dmg       # tạo file cài đặt build/MacCleaner.dmg
```

Mặc định ký bằng chứng chỉ `SIGN_ID` trong `Makefile` để macOS nhớ quyền qua các lần build. Dùng chứng chỉ khác:

```bash
make install SIGN_ID=<SHA-1 của chứng chỉ>
```

Khi đổi chứng chỉ sang team khác, sửa `certificate leaf[subject.OU]` trong `Sources/Shared/FanHelperProtocol.swift` cho khớp team ID, nếu không helper quạt sẽ từ chối kết nối.

## Cấu trúc

```
project.yml                 cấu hình XcodeGen (app, framework, helper, test)
Sources/App/                giao diện SwiftUI, menu bar, kết nối helper
Sources/Core/               logic quét / dọn / tiến trình / quạt (framework MacCleanerCore)
Sources/Shared/             SMC (đọc/ghi quạt, cảm biến) + giao thức XPC, dùng chung app & helper
Sources/Helper/             MacCleanerFanHelper — daemon root ghi SMC, có watchdog
Resources/LaunchDaemons/    plist đăng ký helper qua SMAppService
Tests/CoreTests/            unit test
plans/                      kế hoạch và kết quả kiểm thử từng phần
```

## Gỡ cài đặt

1. Thoát app (quạt tự về Auto), tắt MacCleaner trong System Settings › General › Login Items.
2. Xoá `/Applications/MacCleaner.app`.
3. Dữ liệu còn lại: `~/Library/Application Support/MacCleaner/` (preset quạt), `~/Library/Logs/MacCleaner/`.
