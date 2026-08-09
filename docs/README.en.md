# ctdoshot

**Fast, native macOS screenshot utility for power users.**

Menu-bar capture → annotate → copy/save, built with ScreenCaptureKit, SwiftUI, and Vision. Inspired by Shottr / ShareX-class workflows, tuned for macOS.

**By [ctdoteam](https://github.com/TIPC1110)** · [GitHub](https://github.com/TIPC1110/ctdoshot)

**Languages:** [English](README.en.md) · [Tiếng Việt](README.vi.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [Main README](../README.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://github.com/TIPC1110/ctdoshot)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)

---

## Highlights

| Area | What you get |
|------|----------------|
| **Capture** | Region, fullscreen, active window, last region, scrolling stitch |
| **Editor** | Arrow, text, steps, rect, freehand, **crop**, **pixelate blur**, undo/redo |
| **Export** | Clipboard (⌃C / ⌘C), save PNG/JPEG, file path on pasteboard, pin-to-screen |
| **OCR** | Vision text recognition (EN / VI / JP), history search by OCR |
| **Workflow** | After-capture Show / Copy / Save, Esc actions, recordable global hotkeys |
| **i18n** | English + Vietnamese UI strings |

Bundle ID: `com.ctdoshot.app` · Menu-bar app (`LSUIElement`)

---

## Requirements

- **macOS 13** or later  
- **Screen Recording** permission (System Settings → Privacy & Security)  
- **Xcode 15+** (full Xcode app) to build and run tests  
- Swift 5.9+

> `swift build` may work with Command Line Tools alone. **`swift test` requires full Xcode**.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## Install (from source)

```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot
./scripts/package-app.sh
open build/ctdoshot.app
```

### First launch — Screen Recording

1. Open **System Settings → Privacy & Security → Screen Recording**  
2. Enable **ctdoshot**  
3. **Quit fully** (⌘Q) and open `build/ctdoshot.app` again  

Always use the **packaged** `.app` for capture. `swift run` or binaries under `.build/` use a **different TCC identity**.

If permission loops after a rebuild:

```bash
tccutil reset ScreenCapture com.ctdoshot.app
open build/ctdoshot.app
```

---

## Usage

ctdoshot lives in the **menu bar** (camera / viewfinder icon).

### Capture

| Action | Default hotkey |
|--------|----------------|
| Capture area | ⇧⌘S |
| Capture screen | ⇧⌘3 |
| Capture active window | ⇧⌘W |
| Capture last region | ⇧⌘L |
| Scrolling capture | ⌥⇧⌘X |
| OCR quick (region → clipboard text) | ⌃⌥⌘O |
| History | ⇧⌘H |

Hotkeys are **rebindable** in **Preferences → Hotkeys**.

### Editor

- Draw: arrow, rectangle, pencil, step numbers, text  
- **Crop** and **blur / mosaic**  
- **⌃C** / **⌘C** — copy annotated image  
- **⌘S** / Save & Copy — save (+ path when copy is enabled)  
- **⌘Z** / **⇧⌘Z** — undo / redo  
- Esc — optional copy/save then close (Preferences → Advanced)

### Preferences

Language, save folder/format, after-screenshot actions, OCR options, launch at login, global hotkey recorder.

---

## Development

```bash
swift build
swift build -c release
./scripts/package-app.sh    # → build/ctdoshot.app
swift test
```

```
Sources/
  ctdoshotApp/          # @main entry
  ctdoshotCore/         # capture, editor, OCR, hotkeys, UI
Tests/ctdoshotTests/
packaging/
scripts/package-app.sh
```

- **Capture:** ScreenCaptureKit + region overlay  
- **Annotation:** vector tools, CG bake on export  
- **OCR:** Vision  
- **Hotkeys:** Carbon + `HotkeyStore`  

---

## Contributing

1. Fork and branch (`feature/…` / `fix/…`)  
2. Run `swift test`  
3. Test capture with the packaged `.app`  
4. Open a PR against `main`  

Bug reports: macOS version, launch method (`.app` vs `swift run`), Screen Recording status.

---

## Privacy

ctdoshot runs **locally**. Screenshots and OCR stay on your Mac unless you export them. Screen Recording is used only for captures you request.

---

## License

MIT © **ctdoteam** — see [LICENSE](../LICENSE).

---

## Links

- Repository: https://github.com/TIPC1110/ctdoshot  
- Issues: https://github.com/TIPC1110/ctdoshot/issues  
- Team: **ctdoteam**
