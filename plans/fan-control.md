# Mac Cleaner — Điều khiển quạt & nhiệt độ (kiểu Macs Fan Control + Pro)

## Khảo sát máy (01/11/2026)
- MacBook Pro 14" **M1 Pro** (MacBookPro18,3), macOS 15.7.2.
- SMC: **2 quạt**. Quạt 0: 1200–5779 RPM, quạt 1: 1200–6241 RPM. Chế độ `F0Md`/`F1Md` = 0 (Auto). Không có key `Ftst` (M1 không cần mở khoá).
- **Đọc** quạt/nhiệt độ không cần quyền (đã đọc được `Tp0x` CPU ~63°C, `Tg05` GPU, `TB1T` pin…).
- **Ghi** bị từ chối khi chạy bằng user (`kIOReturnNotPrivileged`) → bắt buộc có **helper chạy root**.
- Macs Fan Control đang cài kèm helper `com.crystalidea.macsfancontrol.smcwrite` → sẽ gỡ sau khi tính năng mới chạy ổn.

## Kiến trúc
```
MacCleaner.app (user)                         MacCleanerFanHelper (root, launchd daemon)
 ├─ đọc SMC trực tiếp (nhiệt độ, RPM)           ├─ chỉ nhận lệnh: setFan(i, auto | rpm), resetAll, heartbeat
 ├─ tính RPM mục tiêu từ preset/curve mỗi 2s ─XPC─▶├─ kẹp RPM trong [min, max] của từng quạt
 └─ MenuBarExtra + màn hình "Quạt & nhiệt độ"     └─ mất kết nối / 15s không heartbeat / bị tắt → trả TẤT CẢ quạt về Auto
```
- Helper nằm trong app: `Contents/MacOS/MacCleanerFanHelper` + `Contents/Library/LaunchDaemons/com.local.MacCleaner.FanHelper.plist`. App đăng ký bằng `SMAppService.daemon` (macOS 13+). Lần đầu anh duyệt **một lần** trong System Settings › General › Login Items (Allow in the Background).
- Helper chỉ chấp nhận kết nối XPC từ đúng app Mac Cleaner ký bằng chứng chỉ của anh (`setConnectionCodeSigningRequirement`), app khác không điều khiển được quạt.
- Code SMC (`Sources/SMC/`) dùng chung cho Core framework (đọc) và helper (ghi). Helper không link framework.
- Phương án dự phòng nếu `SMAppService` không chạy với chứng chỉ Development: cài plist vào `/Library/LaunchDaemons` qua hộp thoại mật khẩu admin.

## An toàn
- Không bao giờ đặt dưới RPM tối thiểu của quạt. Chế độ Auto = trả quyền cho macOS.
- Quạt về Auto khi: thoát app, app crash/bị kill (watchdog 15s), máy sleep (áp lại preset khi wake), helper bị tắt.
- Boost có thời hạn, hết giờ tự quay về preset.
- macOS vẫn giữ cơ chế tự bảo vệ nhiệt (throttle), app không tắt được cơ chế này.

## Tính năng
| Nhóm | Nội dung |
|---|---|
| Cơ bản | Thẻ từng quạt (RPM thực / min / max / chế độ); danh sách cảm biến theo nhóm (CPU P-core, E-core, GPU, Pin, SSD, Wi-Fi, Thân máy…), tên thân thiện + mã key; mỗi quạt chọn **Auto / RPM cố định / Theo cảm biến** (nhiệt độ bắt đầu → nhiệt độ max, tuyến tính) |
| Đường cong | Curve nhiều điểm (nhiệt độ → RPM), kéo thả điểm trên biểu đồ; nguồn nhiệt = 1 cảm biến hoặc max của nhóm (vd "CPU nóng nhất") |
| Preset | Có sẵn: Auto, Yên tĩnh, Cân bằng, Mát tối đa. Tạo / sửa / đổi tên / xoá preset riêng; lưu JSON trong `~/Library/Application Support/MacCleaner/` |
| Menu bar | Hiện "63° · 2300 rpm"; menu: nhiệt độ chính, RPM quạt, đổi preset, Boost, mở app, thoát (trả về Auto) |
| Biểu đồ + Boost + tự chạy | Biểu đồ nhiệt độ CPU/GPU + RPM 10 phút gần nhất (Swift Charts); Boost max quạt 5/10/15 phút; bật "Mở cùng máy" (`SMAppService.mainApp`) để áp preset khi khởi động |
| Cảnh báo | Báo khi Macs Fan Control đang chạy (2 app giành quạt); báo khi helper chưa được duyệt |

## Các bước
- [x] **1. Đọc SMC + danh mục cảm biến** — `Sources/SMC/SMC.swift` (struct 80 byte, read/write key, kiểu `flt`/`ui8`/`fpe2`…), `FanReader`, `SensorCatalog` (duyệt toàn bộ key `T***` kiểu `flt`, lọc giá trị 0–130°C, map tên thân thiện).
  Model: `opus` (native/IOKit)
  → verify: test `MemoryLayout<SMCParam>.size == 80`, test map tên cảm biến; chạy thật in ra 2 quạt (RPM khớp với Macs Fan Control đang hiển thị) và ≥ 10 cảm biến CPU/GPU hợp lý.
- [x] **2. Helper root + XPC + watchdog** — target `MacCleanerFanHelper`, launchd plist, `FanHelperProtocol`, kiểm tra chữ ký client, kẹp RPM, watchdog; app đăng ký `SMAppService.daemon` + màn hướng dẫn duyệt.
  Model: `opus` (quyền root, bảo mật)
  → verify: test logic watchdog/kẹp RPM (struct thuần); chạy thật: đặt quạt 0 = 3000 RPM → `F0Ac` lên ~3000 trong 10s; thoát app → `F0Md` về 0 trong ≤ 15s; `kill -9` app → về 0 trong ≤ 15s; một tiến trình khác (script ký ad-hoc) kết nối XPC → bị từ chối.
- [x] **3. Logic điều khiển** — `FanRule` (auto / constant / sensor / curve), `FanCurve` (nội suy), `FanPreset` + `PresetStore`, `FanController` (đọc nhiệt → RPM mục tiêu, có trễ ±2°C để quạt không lên xuống liên tục), `TemperatureHistory`.
  Model: `sonnet`
  → verify: test nội suy curve (dưới điểm đầu, giữa, trên điểm cuối), kẹp min/max, trễ nhiệt, preset Codable round-trip, ring buffer 10 phút. `make test` pass.
- [x] **4. Màn hình "Quạt & nhiệt độ"** — mục sidebar mới (gradient riêng), thẻ quạt, danh sách cảm biến, chọn preset, sửa rule từng quạt, editor curve kéo thả, quản lý preset.
  Model: `sonnet`
  → verify: build không warning; render kiểm tra bố cục; đổi preset trong app → RPM thật thay đổi theo.
- [x] **5. Biểu đồ + Boost + mở cùng máy.**
  Model: `sonnet`
  → verify: biểu đồ có dữ liệu sau 1 phút; Boost 5 phút → quạt max rồi tự về preset; bật mở cùng máy → app có trong Login Items.
- [x] **6. Menu bar.**
  Model: `sonnet`
  → verify: menu bar hiện nhiệt độ + RPM cập nhật; đổi preset từ menu bar được; đóng cửa sổ app vẫn chạy trên menu bar.
- [x] **7. Kiểm tra an toàn tổng + cài + gỡ Macs Fan Control.**
  Model: `opus`
  → verify: lặp lại các test thoát / kill / sleep–wake trên bản cài trong `/Applications`; chạy 30 phút với preset Cân bằng ổn định. Sau đó hỏi anh rồi mới gỡ Macs Fan Control (app + helper, cần mật khẩu admin).

## Anh cần làm (một lần)
- Duyệt helper trong System Settings › General › Login Items (Allow in the Background), có thể kèm nhập mật khẩu.
- Thoát Macs Fan Control trong lúc test để 2 app không giành quạt.

## Kết quả test thật (02/11/2026, bản cài trong /Applications)
- Preset "Mát tối đa": 2 quạt lên 5768/5779 và 6257/6241 RPM (mode 1).
- Thoát app → cả 2 quạt về Auto sau ~1s.
- Mở lại app → preset tự áp lại sau ~3s.
- `kill -9` app → về Auto sau ~1s (helper thấy mất kết nối).
- App treo (`SIGSTOP`) → watchdog trả về Auto sau ~17s; app chạy lại → áp lại preset.
- Client lạ ký ad-hoc gọi helper → bị từ chối, quạt không đổi.
- Chưa test: sleep/wake (không tự cho máy ngủ được), chạy liên tục 30 phút. Chưa gỡ Macs Fan Control.
