# Architecture & Design

## System Architecture

```
Sources/
├── ctdoshotApp/
│   └── App.swift            # SwiftUI @main entry point
└── ctdoshotCore/
    ├── AppDelegate.swift    # App lifecycle & status bar menu manager
    ├── CaptureEngine.swift  # ScreenCaptureKit orchestrator
    ├── DrawingCanvasView.swift # SwiftUI Canvas & CoreGraphics rendering
    ├── OCRManager.swift     # Apple Vision VNRecognizeTextRequest
    ├── HotkeyManager.swift  # Carbon RegisterEventHotKey global shortcuts
    └── HistoryManager.swift # JSON history persistence
```

## Rendering Pipeline

1. **Interactive Screen Overlay:** Rendered using SwiftUI Canvas for smooth 60fps tracking.
2. **Composite Export:** Rendered using Core Graphics (`CGContext`) on `NSBitmapImageRep` to preserve exact native Retina resolution.
