# Mac Cleaner — app dọn rác macOS (SwiftUI)

## Mục tiêu
App macOS native kiểu CleanMyMac, dùng cá nhân (không lên App Store), gồm 4 nhóm:
rác hệ thống, rác dev React Native, file lớn & cũ, giám sát CPU/RAM.

## Quyết định thiết kế
- **Stack**: SwiftUI, macOS 14+, Swift 6, project sinh bằng `xcodegen` (`project.yml`), không commit `.xcodeproj`.
- **Không sandbox** (sandbox chặn đọc `~/Library`, `~/.gradle`…). Ký ad-hoc, chạy local.
- **Xoá = chuyển vào Thùng rác** (`FileManager.trashItem`). Ngoại lệ duy nhất: mục "Thùng rác" → nút "Dọn Thùng rác" xoá vĩnh viễn, có hộp thoại xác nhận riêng.
- **An toàn**:
  - Không bao giờ tự xoá: luôn Scan → xem danh sách có checkbox → bấm Clean → xác nhận.
  - Chỉ được xoá path nằm trong whitelist gốc (`~/Library/Caches`, `~/Library/Logs`, `~/Library/Developer/...`, `~/.gradle/caches`, `~/.npm/_cacache`, `$TMPDIR`, thư mục project do user chọn…). Path ngoài whitelist, symlink trỏ ra ngoài, `/System`, `/usr` → từ chối (có test).
  - Mọi thao tác ghi log vào `~/Library/Logs/MacCleaner/actions.log`.
- **Giao diện**: sidebar 5 mục — Tổng quan (Smart Scan chạy cả 3 nhóm rác), Rác hệ thống, Rác dev, File lớn & cũ, Tiến trình. Mỗi mục: nút Scan, tổng dung lượng, danh sách nhóm/chi tiết có checkbox, nút Clean.

### Nhóm rác
| Nhóm | Nguồn |
|---|---|
| Hệ thống | `~/Library/Caches/*` (theo app), `~/Library/Logs/*`, `$TMPDIR` cũ > 3 ngày, Thùng rác (`~/.Trash`) |
| Dev RN | Xcode `DerivedData`, `Archives` > 30 ngày, `iOS DeviceSupport` cũ, simulator unavailable (`xcrun simctl delete unavailable`), `~/.gradle/caches`, `~/Library/Caches/CocoaPods`, Metro/haste cache trong `$TMPDIR`, `~/.npm/_cacache`, Yarn cache, `node_modules` / `android/app/build` / `ios/build` trong các project không đụng > 30 ngày (thư mục gốc quét do user chọn, mặc định `/Users/Work`) |
| File lớn & cũ | Quét thư mục user chọn (mặc định `~`): file ≥ 500 MB, hoặc ≥ 50 MB và không mở > 180 ngày; bỏ qua `~/Library`, `.git`, app bundle |
| Tiến trình | `ps` mỗi 2s, top CPU/RAM; cảnh báo tiến trình ăn > 80% CPU liên tục > 5 phút (như vụ opencodex); nút Quit (SIGTERM) / Force Quit (SIGKILL); không cho kill tiến trình của root / `/System` |

## Các bước

- [x] **1. Khung project** — `project.yml`, `Sources/App`, `Sources/Core`, `Tests/CoreTests`, `Makefile` (`make gen|build|test|run`), `.gitignore`. App mở được cửa sổ có sidebar 5 mục trống.
  Model: `sonnet`
  → verify: `make build` thành công; `make run` mở app thấy sidebar 5 mục.

- [x] **2. Core: an toàn + đo dung lượng** — `PathGuard` (whitelist, chặn symlink/system path), `SizeCalculator` (async, đúng allocated size), `Cleaner` (trashItem + log), `CleanItem` model.
  Model: `opus` (phần an toàn xoá file)
  → verify: XCTest với thư mục tạm: path ngoài whitelist bị từ chối, symlink ra ngoài bị từ chối, `/System` bị từ chối; tính đúng size thư mục mẫu; clean xong file nằm trong Thùng rác và có dòng log. `make test` pass.

- [x] **3. Rác hệ thống** — `SystemJunkScanner` + màn hình. Thùng rác có nút xoá vĩnh viễn riêng + xác nhận.
  Model: `sonnet`
  → verify: test scanner trên cây thư mục giả (`$TMPDIR` file mới < 3 ngày không bị liệt kê); chạy app: tổng dung lượng cache khớp `du -sh ~/Library/Caches` (sai lệch < 5%).

- [x] **4. Rác dev RN** — `DevJunkScanner` (các nguồn ở bảng trên) + màn hình + chọn thư mục gốc project.
  Model: `sonnet`
  → verify: test với project giả (node_modules mtime 40 ngày → có, 10 ngày → không); chạy app: DerivedData khớp `du -sh`; dọn thử DerivedData, Xcode build lại GF-APP-CALL được.

- [x] **5. File lớn & cũ** — `LargeFileScanner` + màn hình (sort theo size/ngày, Reveal in Finder).
  Model: `sonnet`
  → verify: test với file sparse 600 MB + file atime 200 ngày → liệt kê, file nhỏ mới → không; quét `~` không treo UI (có progress, Cancel được).

- [x] **6. Tiến trình** — `ProcessMonitor` (parse `ps`), màn hình bảng + cảnh báo + Quit/Force Quit.
  Model: `sonnet`
  → verify: test parse output `ps` mẫu (cả tên có dấu cách); chạy `yes > /dev/null` → app cảnh báo sau ngưỡng (hạ ngưỡng khi test), Quit được; tiến trình root không có nút kill.

- [x] **7. Smart Scan + hoàn thiện** — trang Tổng quan chạy 3 scanner song song, tổng dung lượng, Clean all đã chọn; icon app; `make install` copy vào `/Applications`.
  Model: `sonnet`
  → verify: Smart Scan ra tổng = tổng 3 nhóm; `make test` pass; app chạy từ `/Applications`.

## Lưu ý
- Lần đầu chạy, một số thư mục (Mail, Safari, `~/Library/Containers`) cần Full Disk Access — app sẽ hiện hướng dẫn cấp quyền thay vì crash; không quét các thư mục đó trong bản đầu.
- Không có: gỡ app, dọn RAM ("purge"), tự động chạy nền — có thể thêm sau nếu cần.

## Kết quả verify (01/11/2026)
- `make test`: 37 test pass (PathGuard, SizeCalculator, Cleaner, 3 scanner, ProcessMonitor).
- Chạy scanner trên dữ liệu thật: cache 5,83 GB + CocoaPods/Yarn 2,43 GB (nằm ở nhóm dev) = 8,26 GB, khớp `du` 8,25 GB.
- Quét `/Users/Work` mất 1,9 giây (32k file). Ở thư mục home, Desktop/Documents/Downloads cần quyền → app hiện cảnh báo.
- Tiến trình: `yes` 99% CPU được phát hiện sau ngưỡng, SIGTERM thành công, có ghi log.
- Chưa kiểm tra bằng mắt giao diện (không chụp được màn hình) — cần anh xem trực tiếp.
