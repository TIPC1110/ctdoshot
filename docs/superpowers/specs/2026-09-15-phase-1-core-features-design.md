# Design Spec: Phase 1 Core Features (Screen Recording HUD, Editor Tools & Barcode/QR OCR)

- **Date:** 2026-09-15
- **Status:** Approved
- **Targets:** `ctdoshotCore`, `ctdoshotApp`

---

## 1. Overview

Phase 1 completes high-value user-facing features:
1. Connect `ScreenRecorder` to Menu Bar and provide a Floating HUD controller for recording management.
2. Extend `DrawingCanvasView` with stroke width options, 6-color palette, and canvas zoom controls (closing GitHub Issue #1).
3. Enhance `OCRManager` with Vision barcode/QR code detection (`VNDetectBarcodesRequest`).

---

## 2. Architecture & Components

### 2.1 Screen Recording Integration & HUD Controller
- **Menu Bar Additions** (`Sources/ctdoshotCore/AppDelegate.swift`):
  - Add items to Status Menu:
    - "Record Screen" (`menu.record_screen`)
    - "Record Area..." (`menu.record_area`)
  - Track active recording session in `AppDelegate`.
- **Floating HUD** (`Sources/ctdoshotCore/HUDController.swift`):
  - Lightweight non-activating `NSPanel` (`.floating` window level).
  - Controls:
    - Stop button (terminates recording, triggers save/export).
    - Pause / Resume toggle button.
    - Elapsed timer display (`00:00`).
    - Microphone toggle button (binds to `ScreenRecorder.isMicEnabled`).
  - Position: Pinned to bottom-center of the screen being recorded.
- **Output Hand-off**:
  - Once stopped, `ScreenRecorder` saves MP4/GIF to target path.
  - Automatically registers output to `HistoryManager` and copies to pasteboard/notification via `OutputManager`.

### 2.2 Editor Enhancements (Issue #1)
- **Stroke Width** (`Sources/ctdoshotCore/DrawingCanvasView.swift`):
  - Width presets: Fine (2pt), Medium (4pt - default), Bold (8pt).
  - Update `ShapeElement` to store `lineWidth: CGFloat`.
  - Render strokes using the element's configured line width.
- **Color Palette**:
  - Quick-select buttons for 6 high-contrast colors: Red, Green, Blue, Yellow, White, Black.
- **Canvas Zoom & Pan**:
  - State: `zoomScale: CGFloat` (range 0.5 to 3.0, step 0.25).
  - Keyboard shortcuts: `⌘+` (Zoom In), `⌘-` (Zoom Out), `⌘0` (Reset to 1.0).
  - Wraps drawing canvas in scrollable container when zoomed > 1.0.

### 2.3 Barcode & QR Code OCR Recognition
- **Vision Barcode Request** (`Sources/ctdoshotCore/OCRManager.swift`):
  - Concurrently run `VNDetectBarcodesRequest` alongside text recognition.
  - Supported symbiology: QR, DataMatrix, Code128, EAN13, etc.
  - If a barcode/QR payload is detected:
    - Format payload with priority header (e.g. `[QR/Barcode] https://...`).
    - Copy to pasteboard and display in OCR result dialog.

---

## 3. Verification & Testing

1. `swift build`: Verify zero compiler warnings or errors.
2. `swift test`: Run unit tests (`CaptureGeometryTests`, `CanvasStateTests`, etc.).
3. Packaged smoke test: `./scripts/package-app.sh` to ensure bundle packaging succeeds.
