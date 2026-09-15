# Phase 1 Core Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 1 features: Barcode/QR OCR recognition, DrawingCanvasView stroke width/colors/zoom controls, and ScreenRecorder Menu integration with Floating HUD.

**Architecture:**
- Native AppKit/SwiftUI + Vision (`VNDetectBarcodesRequest`) + ScreenCaptureKit + AVFoundation.
- YAGNI/ponytail principles: minimal boilerplate, native platform APIs, no third-party dependencies.

---

## Tasks

### Task 1: Barcode & QR Code Recognition in OCRManager

**Files:**
- Modify: `Sources/ctdoshotCore/OCRManager.swift`
- Test: `swift build`

- [ ] **Step 1:** In `OCRManager.swift`, add a helper or extend `recognizeText(in:completion:)` to execute a `VNDetectBarcodesRequest` alongside the text recognition request.
- [ ] **Step 2:** Extract payload strings from detected barcode/QR observations (`observation.payloadStringValue`).
- [ ] **Step 3:** If QR/barcode found, prepend or format the payload into the returned text (e.g. `[QR/Barcode: <payload>]\n\n<text>`).
- [ ] **Step 4:** Verify compilation with `swift build`.

---

### Task 2: Editor Tools — Stroke Width, Color Palette & Zoom

**Files:**
- Modify: `Sources/ctdoshotCore/DrawingCanvasView.swift`
- Test: `swift build`

- [ ] **Step 1:** In `ShapeElement`, add `lineWidth: CGFloat` property (default `4.0`) and update render methods (`drawElement`, pencil path stroke) to use this width.
- [ ] **Step 2:** In `DrawingCanvasView`, add `@State private var selectedLineWidth: CGFloat = 4.0` and a toolbar picker with 3 presets: Fine (2pt), Medium (4pt), Bold (8pt).
- [ ] **Step 3:** Expand color picker options to 6 standard colors: Red, Green, Blue, Yellow, White, Black.
- [ ] **Step 4:** Add `@State private var zoomScale: CGFloat = 1.0` and shortcuts:
  - `⌘+` / `⌘=` to zoom in (up to 3.0x, step 0.25).
  - `⌘-` to zoom out (down to 0.5x, step 0.25).
  - `⌘0` to reset zoom to 1.0x.
- [ ] **Step 5:** Wrap editor canvas in a scrollable frame when `zoomScale > 1.0`.
- [ ] **Step 6:** Verify compilation with `swift build`.

---

### Task 3: Floating HUD & Screen Recording Menu Integration

**Files:**
- Modify: `Sources/ctdoshotCore/HUDController.swift`
- Modify: `Sources/ctdoshotCore/AppDelegate.swift`
- Modify: `Sources/ctdoshotCore/I18n.swift`
- Test: `swift build`

- [ ] **Step 1:** In `I18n.swift`, add localized keys for recording actions:
  - `menu.record_screen` ("Record Screen" / "Quay toàn màn hình")
  - `menu.record_area` ("Record Area..." / "Quay vùng chọn...")
  - `hud.stop` ("Stop" / "Dừng")
  - `hud.pause` ("Pause" / "Tạm dừng")
  - `hud.resume` ("Resume" / "Tiếp tục")
- [ ] **Step 2:** In `HUDController.swift`, build an `NSPanel` floating HUD hosting a SwiftUI view:
  - Displays record timer (`00:00`), Stop button (calls stop action), Pause/Resume toggle, and Mic toggle.
  - Non-activating, floating window level (`.floating`), positioned at bottom center of screen.
- [ ] **Step 3:** In `AppDelegate.swift`:
  - Add "Record Screen" and "Record Area..." menu items to Status Menu and Main Menu.
  - Implement handlers `triggerScreenRecording()` and `triggerRegionRecording()` using `ScreenRecorder`.
  - Wire recording state to `HUDController` to show HUD on start, update timer, and hide HUD on stop.
  - On recording completion, register file to `HistoryManager` and notify user via `OutputManager`.
- [ ] **Step 4:** Verify compilation with `swift build`.

---

### Task 4: Full Suite Verification & App Packaging

**Files:**
- Test suite: `swift test` or `./scripts/package-app.sh`

- [ ] **Step 1:** Run `swift build` and ensure clean build.
- [ ] **Step 2:** Run `./scripts/package-app.sh` to produce packaged `build/ctdoshot.app`.
- [ ] **Step 3:** Verify all modified files adhere to YAGNI and ponytail standards.
