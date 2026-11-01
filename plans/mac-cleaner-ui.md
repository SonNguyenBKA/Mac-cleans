# Mac Cleaner — đổi giao diện theo phong cách CleanMyMac

Lấy cảm hứng từ bố cục và cảm giác của CleanMyMac (nền gradient tối, nút tròn lớn ở giữa, thẻ kính mờ), không copy logo, tên hay hình minh hoạ của họ. Chỉ đổi phần `Sources/App`, không đụng `Sources/Core`.

## Thiết kế
- **Nền**: mỗi mục một gradient tối riêng, luôn dùng dark mode, chữ trắng.
  - Tổng quan: tím → xanh dương
  - Rác hệ thống: hồng → tím
  - Rác dev: xanh lá → xanh ngọc
  - File lớn & cũ: cam → đỏ
  - Tiến trình: xanh dương → xanh ngọc
- **Sidebar**: trong suốt trên nền gradient. Mỗi mục có ô icon bo tròn tô màu. Thanh dung lượng ổ đĩa đặt cuối sidebar, dạng thẻ kính mờ.
- **Màn hình chưa quét**: icon lớn có glow, tiêu đề, mô tả 1 dòng, 3 gạch đầu dòng tính năng, **nút tròn "Quét" lớn ở giữa dưới**.
- **Đang quét**: vòng tiến trình quay quanh nút tròn, kèm số file đã quét và nút Dừng.
- **Kết quả**: số dung lượng rất lớn ở giữa, danh sách nhóm trong thẻ kính mờ (mở ra xem chi tiết, tích chọn), **nút tròn "Dọn"** ở giữa dưới, hộp xác nhận giữ nguyên (Thùng rác / Xoá vĩnh viễn).
- **Tổng quan (Smart Scan)**: sau khi quét hiện 3 thẻ kết quả (hệ thống, dev, file lớn) với số GB, bấm vào thẻ để mở chi tiết; cảnh báo CPU dạng thẻ đỏ.
- **Tiến trình**: bảng trên nền kính mờ, thẻ cảnh báo tiến trình nóng ở trên.

## Các bước
- [x] **1. Theme + component dùng chung** — `Theme.swift` (gradient, màu, icon, mô tả từng mục), `Components.swift` (`GlassCard`, `RoundActionButton` có vòng progress, `HeroView`), sidebar mới + thanh ổ đĩa kiểu thẻ.
  Model: `sonnet`
  → verify: `make build` không lỗi/warning; sidebar hiện 5 ô icon màu, nền gradient đổi theo mục.
- [x] **2. Tổng quan** — viết lại `OverviewView` theo 3 trạng thái: chưa quét / đang quét / kết quả.
  Model: `sonnet`
  → verify: bấm Quét → vòng progress chạy → hiện 3 thẻ có số khớp từng mục; bấm thẻ sẽ mở mục đó.
- [x] **3. Màn hình rác (hệ thống / dev / file lớn)** — viết lại `JunkSectionView` theo 3 trạng thái, giữ nguyên logic `JunkSection`.
  Model: `sonnet`
  → verify: quét, tích/bỏ chọn, Dọn (cả 2 kiểu) vẫn hoạt động; chọn thư mục gốc vẫn được.
- [x] **4. Tiến trình** — style lại `ProcessesView`.
  Model: `sonnet`
  → verify: bảng cập nhật mỗi 2s; Quit/Force Quit vẫn có xác nhận.
- [x] **5. Cài lại + kiểm tra giao diện** — `make test`, `make install`.
  → verify: 41 test pass; anh xem app (hoặc bật Computer use để em tự chụp màn hình kiểm tra).
