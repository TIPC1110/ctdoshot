# ctdoshot

**Fast, native macOS screenshot utility for power users.**

Menu-bar capture → annotate → copy/save, built with ScreenCaptureKit, SwiftUI, and Vision. Inspired by Shottr / ShareX-class workflows, tuned for macOS.

**By [ctdoteam](https://github.com/TIPC1110)** · [GitHub](https://github.com/TIPC1110/ctdoshot)

**Documentation / 文档 / ドキュメント:**  
[English](docs/README.en.md) · [Tiếng Việt](docs/README.vi.md) · [简体中文](docs/README.zh-CN.md) · [日本語](docs/README.ja.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://github.com/TIPC1110/ctdoshot)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## Highlights

| Area | What you get |
|------|----------------|
| **Capture** | Region, fullscreen, active window, last region, scrolling stitch |
| **Editor** | Arrow, text, steps, rect, freehand, **crop**, **pixelate blur**, undo/redo |
| **Export** | Clipboard (⌃C / ⌘C), save PNG/JPEG, file path on pasteboard, pin-to-screen |
| **OCR** | Vision text recognition (EN / VI / JP), history search by OCR |
| **Workflow** | After-capture Show / Copy / Save, Esc actions, recordable global hotkeys |
| **i18n** | English + Tiếng Việt UI strings |

Bundle ID: `com.ctdoshot.app` · Menu-bar app (`LSUIElement`)

---

## Screenshots

> Add product shots under `docs/images/` when available.

| Capture overlay | Editor | Preferences |
|-----------------|--------|-------------|
| *Coming soon* | *Coming soon* | *Coming soon* |

---

## Requirements

- **macOS 13** or later  
- **Screen Recording** permission (System Settings → Privacy & Security)  
- **Xcode 15+** (or full Xcode app) to build and run tests  
- Swift 5.9+

> `swift build` may work with Command Line Tools alone. **`swift test` requires full Xcode** (`xcode-select` must point at an Xcode.app).

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## Install (from source)

```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot

# Release .app with stable codesign identity (recommended)
./scripts/package-app.sh
open build/ctdoshot.app
```

### First launch — Screen Recording

1. Open **System Settings → Privacy & Security → Screen Recording**  
2. Enable **ctdoshot**  
3. **Quit fully** (⌘Q) and open `build/ctdoshot.app` again  

Always use the **packaged** `.app` for capture. Running `swift run` or a raw binary under `.build/` creates a **different TCC identity** and will re-prompt or fail silently.

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

Hotkeys are **rebindable** in **Preferences → Hotkeys** (click a row, press a new chord).

### Editor

After capture (when “Show” is enabled):

- Draw: arrow, rectangle, pencil, step numbers, text  
- **Crop** and **blur / mosaic** (pixelate)  
- **⌃C** / **⌘C** — copy annotated image (editor stays open)  
- **⌘S** / Save & Copy — save file (+ path on clipboard when copy is on)  
- **⌘Z** / **⇧⌘Z** — undo / redo  
- Esc — optional copy/save then close (Preferences → Advanced)

### Preferences

- Language (System / English / Tiếng Việt)  
- Save folder, format (PNG / Auto JPEG), downscale Retina  
- After screenshot: Show / Copy / Save  
- OCR language, strip line breaks  
- Launch at login  
- Global hotkey recorder  

---

## Development

### Project layout

```
Sources/
  ctdoshotApp/          # @main entry
  ctdoshotCore/         # App logic (capture, editor, OCR, hotkeys, UI)
Tests/ctdoshotTests/    # XCTest
packaging/              # Info.plist, entitlements
scripts/package-app.sh  # release .app + ad-hoc codesign
```

### Build

```bash
swift build                 # debug
swift build -c release      # release binary → .build/release/ctdoshot
./scripts/package-app.sh    # → build/ctdoshot.app (Identifier=com.ctdoshot.app)
```

### Test

```bash
swift test
# or explicitly:
DEVELOPER_DIR="$(xcode-select -p)" swift test
```

### Architecture (short)

- **Capture:** ScreenCaptureKit (in-process; no `screencapture` CLI) + region overlay  
- **Annotation:** vector tools, image-space coordinates, CG bake on export  
- **OCR:** Vision `VNRecognizeTextRequest`  
- **Hotkeys:** Carbon `RegisterEventHotKey` + `HotkeyStore` persistence  

---

## Roadmap

Planned / partial (see design docs):

- [ ] Richer scrolling stitch reliability  
- [ ] Window capture background styles (wallpaper / shadow trim)  
- [ ] Video / GIF recording  
- [ ] Upload destinations (optional plugins)  
- [ ] Notarized release builds  

Contributions welcome — open an issue first for large features.

---

## Contributing

1. Fork the repo and create a branch (`feature/…` or `fix/…`)  
2. Keep changes focused; run `swift test` before pushing  
3. Prefer packaged-app testing for anything involving Screen Recording  
4. Open a Pull Request against `main` with a clear description  

Bug reports: include macOS version, how you launched the app (`.app` vs `swift run`), and whether Screen Recording is enabled for **ctdoshot**.

---

## Privacy

ctdoshot runs **locally**. Screenshots and OCR stay on your Mac unless you copy, save, or share them yourself. Screen Recording is used only to capture displays/windows you request.

---

## Acknowledgments

- Built for everyday capture workflows on macOS  
- Concepts familiar from tools like Shottr and ShareX — implemented natively with Apple frameworks  

---

## License

MIT © **ctdoteam**

```
Copyright (c) ctdoteam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Documentation (localized)

| Language | File |
|----------|------|
| English | [docs/README.en.md](docs/README.en.md) |
| Tiếng Việt | [docs/README.vi.md](docs/README.vi.md) |
| 简体中文 | [docs/README.zh-CN.md](docs/README.zh-CN.md) |
| 日本語 | [docs/README.ja.md](docs/README.ja.md) |


---

## Links

- **Repository:** https://github.com/TIPC1110/ctdoshot  
- **Issues:** https://github.com/TIPC1110/ctdoshot/issues  
- **Team:** ctdoteam  

---

<p align="center">
  <sub>ctdoshot by ctdoteam — capture more, friction less.</sub>
</p>
