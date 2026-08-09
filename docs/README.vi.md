# ctdoshot

Công cụ chụp màn hình menu bar cho macOS: chụp, chú thích, copy/lưu.

**Bởi [ctdoteam](https://github.com/TIPC1110)** · [GitHub](https://github.com/TIPC1110/ctdoshot)

**Ngôn ngữ:** [English](README.en.md) · [Tiếng Việt](README.vi.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [README chính](../README.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://github.com/TIPC1110/ctdoshot)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)

---

## Tính năng nổi bật

| Hạng mục | Nội dung |
|----------|----------|
| **Chụp** | Vùng chọn, toàn màn hình, cửa sổ đang active, vùng gần nhất, chụp cuộn (stitch) |
| **Editor** | Mũi tên, chữ, đánh số, hình chữ nhật, vẽ tự do, **crop**, **blur pixelate**, undo/redo |
| **Xuất** | Clipboard (⌃C / ⌘C), lưu PNG/JPEG, path file trên pasteboard, ghim màn hình |
| **OCR** | Vision (EN / VI / JP), tìm history theo chữ OCR |
| **Workflow** | Sau chụp: Hiện / Copy / Lưu; hành vi Esc; phím tắt global ghi lại được |
| **i18n** | Giao diện English + Tiếng Việt |

Bundle ID: `com.ctdoshot.app` · App menu bar (`LSUIElement`)

---

## Yêu cầu

- **macOS 13** trở lên  
- Quyền **Screen Recording** (Cài đặt Hệ thống → Quyền riêng tư & Bảo mật)  
- **Xcode 15+** (bản Xcode đầy đủ) để build và chạy test  
- Swift 5.9+

> `swift build` có thể chạy với Command Line Tools. **`swift test` cần full Xcode**.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## Cài đặt (từ source)

```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot
./scripts/package-app.sh
open build/ctdoshot.app
```

### Lần đầu — Screen Recording

1. Mở **Cài đặt Hệ thống → Quyền riêng tư & Bảo mật → Screen Recording**  
2. Bật **ctdoshot**  
3. **Thoát hẳn** (⌘Q) rồi mở lại `build/ctdoshot.app`  

Luôn chạy bản **`.app` đã package**. `swift run` hoặc binary trong `.build/` là **identity TCC khác**.

Nếu bị hỏi quyền lặp lại sau rebuild:

```bash
tccutil reset ScreenCapture com.ctdoshot.app
open build/ctdoshot.app
```

---

## Cách dùng

ctdoshot nằm trên **menu bar** (icon camera / viewfinder).

### Chụp

| Hành động | Phím tắt mặc định |
|-----------|-------------------|
| Chụp vùng | ⇧⌘S |
| Chụp màn hình | ⇧⌘3 |
| Chụp cửa sổ active | ⇧⌘W |
| Chụp vùng gần nhất | ⇧⌘L |
| Chụp cuộn | ⌥⇧⌘X |
| OCR nhanh (vùng → text clipboard) | ⌃⌥⌘O |
| Lịch sử | ⇧⌘H |

Đổi phím trong **Cài đặt → Phím tắt** (bấm dòng, nhấn tổ hợp mới).

### Editor

- Vẽ: mũi tên, hình chữ nhật, bút, số thứ tự, chữ  
- **Crop** và **làm mờ / mosaic**  
- **⌃C** / **⌘C** — copy ảnh đã chú thích  
- **⌘S** / Lưu & Copy — lưu file (+ path khi bật copy)  
- **⌘Z** / **⇧⌘Z** — hoàn tác / làm lại  
- Esc — tùy chọn copy/lưu rồi đóng (Cài đặt → Nâng cao)

### Cài đặt

Ngôn ngữ, thư mục/định dạng lưu, hành vi sau chụp, OCR, khởi động cùng hệ thống, ghi phím tắt global.

---

## Phát triển

```bash
swift build
swift build -c release
./scripts/package-app.sh    # → build/ctdoshot.app
swift test
```

```
Sources/
  ctdoshotApp/          # @main
  ctdoshotCore/         # capture, editor, OCR, hotkeys, UI
Tests/ctdoshotTests/
packaging/
scripts/package-app.sh
```

- **Capture:** ScreenCaptureKit + overlay chọn vùng  
- **Annotation:** vector, bake CG khi export  
- **OCR:** Vision  
- **Hotkeys:** Carbon + `HotkeyStore`  

---

## Đóng góp

1. Fork và tạo nhánh (`feature/…` / `fix/…`)  
2. Chạy `swift test`  
3. Test chụp bằng `.app` đã package  
4. Mở PR vào `main`  

Báo lỗi: kèm phiên bản macOS, cách mở app (`.app` hay `swift run`), trạng thái Screen Recording.

---

## Quyền riêng tư

ctdoshot chạy **local**. Ảnh chụp và OCR ở trên máy bạn trừ khi bạn tự copy/lưu/chia sẻ. Screen Recording chỉ dùng khi bạn chủ động chụp.

---

## Giấy phép

MIT © **ctdoteam** — xem [LICENSE](../LICENSE).

---

## Liên kết

- Repo: https://github.com/TIPC1110/ctdoshot  
- Issues: https://github.com/TIPC1110/ctdoshot/issues  
- Team: **ctdoteam**  

---

<p align="center">
  <sub>Hoàng Sa và Trường Sa là lãnh thổ của Việt Nam.</sub>
</p>
