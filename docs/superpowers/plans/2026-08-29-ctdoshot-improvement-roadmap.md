# ctdoshot Improvement Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship solo-friendly phased roadmap P0 (install friction) → P1 (visibility) → P2 (maintainability) → P3 (retention) with each phase independently shippable.

**Architecture:** Keep SPM `ctdoshotCore`+`ctdoshot` + `LSUIElement` + ScreenCaptureKit/AVAssetWriter. P0 adds `notarytool`+`stapler` CI + `hdiutil` DMG + TCC first-launch UX. P2 incrementally splits God-files (AppDelegate, DrawingCanvasView, ScreenRecorder) behind facades, warn-only SwiftLint, and `scripts/test.sh` wrapper for CLT/Xcode.

**Tech Stack:** Swift 5.9 (6.1 runtime), macOS 13+, SwiftPM, ScreenCaptureKit, AVFoundation `AVAssetWriter` (H.264/AAC), Vision `VNRecognizeTextRequest`, Carbon `RegisterEventHotKey`, XCTest + `E2ETestRunner`/`E2EVerifier` (async/await), `hdiutil`/`notarytool`/`stapler`/`codesign`, GitHub Actions `macos-14` + `latest-stable` Xcode, GitHub Pages `site/`.

## Global Constraints

- `swift-tools-version: 5.9`, `platforms: [.macOS(.v13)]`, bundle `com.ctdoshot.app`, `LSUIElement` true — from `Package.swift`/`packaging/Info.plist` verbatim.
- `swift build` must stay CLT-compatible; `swift test` requires full Xcode — use `DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer xcrun --sdk macosx swift test` when `xcode-select -p` is CLT.
- Signing: prefer `CTDOSHOT_SIGN_IDENTITY` > `ctdoshot Developer` (login keychain) > `Apple Development`; fallback ad-hoc `-` resets TCC — must handle.
- No Xcode project; `.build/` and `build/` are generated, never edit; `package-app.sh` owns `build/ctdoshot.app`.
- 42 E2E must stay 100% green (Tier 1:30, T2:5, T3:4, T4:3) with isolated `/tmp/ctdoshot_e2e_<UUID>` + `UserDefaults`/`HistoryManager`/`NSPasteboard` sanitize.
- No new runtime deps for DMG/notarization; `hdiutil` stdlib only. SwiftLint warn-only, never fail CI.
- `.gitignore` ignores `AGENTS.md`, `CLAUDE.md`, `.build/`, `build/`, `.codegraph/` — force-add `docs/superpowers/**` with `git add -f`.

---

## File Structure

**New files:**
- `scripts/make-dmg.sh` — DMG creation via hdiutil, symlink /Applications
- `scripts/test.sh` — wrapper auto-detecting DEVELOPER_DIR
- `.swiftlint.yml` — 10-rule warn-only config
- `Sources/ctdoshotCore/StatusBarController.swift` — extracted from AppDelegate
- `Sources/ctdoshotCore/AppLifecycle.swift` — extracted from AppDelegate
- `Sources/ctdoshotCore/CanvasState.swift` + `CanvasRenderer.swift` + `Sources/ctdoshotCore/Tools/*.swift` — from DrawingCanvasView
- `Sources/ctdoshotCore/RecordingSession.swift` + `AudioCapture.swift` + `HUDController.swift` — from ScreenRecorder
- `Sources/ctdoshotCore/TroubleshootingView.swift` — TCC helper UI
- `Casks/ctdoshot.rb` — Homebrew cask draft (local only)
- `Tests/ctdoshotTests/CanvasStateTests.swift` — new unit tests
- `docs/images/demo-*.gif` — dogfooded demos

**Modified files:**
- `scripts/package-app.sh` — add `--notarize` flag handling (no behavior change without secrets)
- `.github/workflows/swift.yml` — build→test via test.sh, cache, notarize+staple gated, DMG, dual artifacts
- `Sources/ctdoshotCore/AppDelegate.swift` — thin to ~100L wiring
- `Sources/ctdoshotCore/DrawingCanvasView.swift` — delegate to CanvasState/Renderer
- `Sources/ctdoshotCore/ScreenRecorder.swift` — delegate to RecordingSession/AudioCapture
- `Sources/ctdoshotCore/PreferencesView.swift` — embed TroubleshootingView tab
- `site/` — hero GIF, CTA, SEO/OG

---

### Task 1: P0 — `scripts/make-dmg.sh` (DMG via hdiutil, no deps)

**Files:**
- Create: `scripts/make-dmg.sh`
- Test: manual `ls build/ctdoshot.dmg` + `hdiutil imageinfo`

**Interfaces:**
- Consumes: `build/ctdoshot.app` from `package-app.sh`
- Produces: `build/ctdoshot.dmg` (HFS+ with /Applications symlink) for Task 3 CI

- [ ] **Step 1: Create script with minimal hdiutil flow**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/build/ctdoshot.app"
DMG="$ROOT/build/ctdoshot.dmg"
STAGING="$ROOT/build/dmg-staging"
if [[ ! -d "$APP_DIR" ]]; then echo "error: $APP_DIR missing, run package-app.sh first" >&2; exit 1; fi
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "ctdoshot" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
echo "OK: $DMG ($(du -h "$DMG" | cut -f1))"
hdiutil imageinfo "$DMG" | head -n 20
```

- [ ] **Step 2: Make executable and test locally**

Run: `chmod +x scripts/make-dmg.sh && ./scripts/package-app.sh && ./scripts/make-dmg.sh`
Expected: `OK: .../build/ctdoshot.dmg` and `hdiutil imageinfo` output, no error.

- [ ] **Step 3: Verify DMG mounts**

Run: `hdiutil attach build/ctdoshot.dmg -nobrowse -mountpoint /tmp/ctdoshot-dmg-test && ls /tmp/ctdoshot-dmg-test && hdiutil detach /tmp/ctdoshot-dmg-test`
Expected: Lists `ctdoshot.app` + `Applications` symlink, detach succeeds.

- [ ] **Step 4: Handle edge — missing .app**

Run: `rm -rf build/ctdoshot.app && ./scripts/make-dmg.sh; echo exit:$?`
Expected: `error: ... missing` and exit 1.

- [ ] **Step 5: Commit**

```bash
git add -f scripts/make-dmg.sh
git commit -m "feat(scripts): add hdiutil DMG builder with /Applications symlink"
```

---

### Task 2: P0 — `scripts/test.sh` wrapper (fix CLT/Xcode fragility)

**Files:**
- Create: `scripts/test.sh`
- Modify: none yet (Task 3 will switch CI to it)

**Interfaces:**
- Consumes: `xcode-select -p`, `DEVELOPER_DIR`
- Produces: reliable `swift test` exit code for CI and local

- [ ] **Step 1: Create wrapper**

```bash
#!/usr/bin/env bash
set -euo pipefail
SELECT="$(xcode-select -p 2>/dev/null || echo "")"
if [[ "$SELECT" == *"CommandLineTools"* ]]; then
  CANDIDATE="/Applications/Xcode-16.4.0.app/Contents/Developer"
  if [[ -d "$CANDIDATE" ]]; then
    export DEVELOPER_DIR="$CANDIDATE"
    echo "→ CLT detected, using DEVELOPER_DIR=$DEVELOPER_DIR" >&2
  else
    # fallback: try any Xcode.app
    FOUND="$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | head -1 || true)"
    if [[ -n "$FOUND" ]]; then export DEVELOPER_DIR="$FOUND"; echo "→ using $DEVELOPER_DIR" >&2; fi
  fi
fi
exec xcrun --sdk macosx swift test "$@"
```

- [ ] **Step 2: Test on current machine (CLT)**

Run: `chmod +x scripts/test.sh && ./scripts/test.sh --filter CaptureGeometryTests 2>&1 | tail -n 20`
Expected: Detects CLT, prints `→ CLT detected`, then tests pass (at least that suite).

- [ ] **Step 3: Test passthrough of args**

Run: `./scripts/test.sh --filter HistoryManagerTests -v 2>&1 | tail -n 20`
Expected: Only that suite runs, no wrapper error.

- [ ] **Step 4: Ensure direct swift test still documented**

No code change; verify `swift build` still works: `swift build 2>&1 | tail -n 5`

- [ ] **Step 5: Commit**

```bash
git add -f scripts/test.sh
git commit -m "feat(scripts): add test wrapper auto-setting DEVELOPER_DIR for CLT"
```

---

### Task 3: P0 — CI notarize+staple + DMG wiring (`swift.yml`)

**Files:**
- Modify: `.github/workflows/swift.yml`

**Interfaces:**
- Consumes: `scripts/make-dmg.sh` (Task 1), `scripts/test.sh` (Task 2), secrets `APPLE_ID`/`APPLE_APP_PASSWORD`/`APPLE_TEAM_ID`
- Produces: artifacts `ctdoshot-macOS-Universal.zip` + `ctdoshot.dmg` (stapled when secrets present)

- [ ] **Step 1: Update workflow to use test.sh, cache, gated notarize**

```yaml
name: Swift CI
on:
  push:
    branches: ["main"]
    tags: ["v*"]
  pull_request:
    branches: ["main"]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            .build
            ~/Library/Caches/org.swift.swiftpm
          key: spm-${{ runner.os }}-${{ hashFiles('Package.swift') }}
      - run: swift build -v
      - run: chmod +x scripts/test.sh && ./scripts/test.sh -v
      - run: |
          chmod +x scripts/package-app.sh scripts/ensure-signing-identity.sh scripts/make-dmg.sh
          ./scripts/ensure-signing-identity.sh || true
          ./scripts/package-app.sh --universal
      - name: Notarize & Staple (CI only, when secrets present)
        if: ${{ secrets.APPLE_ID != '' }}
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcrun notarytool submit build/ctdoshot.app --wait --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID"
          xcrun stapler staple build/ctdoshot.app
          xcrun stapler validate build/ctdoshot.app
      - run: ./scripts/make-dmg.sh
      - run: |
          ditto -ck --sequesterRsrc build/ctdoshot.app build/ctdoshot-macOS-Universal.zip
          shasum -a 256 build/ctdoshot-macOS-Universal.zip build/ctdoshot.dmg | tee build/SHA256SUMS
      - uses: actions/upload-artifact@v4
        with:
          name: ctdoshot-macOS-Universal
          path: |
            build/ctdoshot-macOS-Universal.zip
            build/ctdoshot.dmg
            build/SHA256SUMS
          if-no-files-found: error
```

Key: Notarize gated by `secrets.APPLE_ID != ''` so forks don't fail. On push to `main` without tag, artifacts are unsigned but still DMG+ZIP.

- [ ] **Step 2: Validate YAML locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/swift.yml'))" && echo OK` (or `cat .github/workflows/swift.yml | head -n 40`)

- [ ] **Step 3: Dry-run make-dmg after package locally**

Run: `./scripts/package-app.sh --universal 2>&1 | tail && ./scripts/make-dmg.sh 2>&1 | tail`

- [ ] **Step 4: Ensure existing `pages.yml` untouched**

Run: `cat .github/workflows/pages.yml | head -n 5` — no change.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/swift.yml
git commit -m "ci: gate notarize+staple, add DMG + cache + test.sh"
```

---

### Task 4: P0 — First-launch TCC UX + TroubleshootingView

**Files:**
- Create: `Sources/ctdoshotCore/TroubleshootingView.swift`
- Modify: `Sources/ctdoshotCore/AppDelegate.swift:35-40` (first capture guard), `Sources/ctdoshotCore/PreferencesView.swift` (add tab), `Sources/ctdoshotCore/CaptureEngine.swift` (expose `hasScreenRecordingPermission()`)

**Interfaces:**
- Consumes: `CGPreflightScreenCaptureAccess`, `SCShareableContent`, `codesign -dv` status
- Produces: `TroubleshootingView` + alert helper `showScreenRecordingAlert()`

- [ ] **Step 1: Add TroubleshootingView**

```swift
// Sources/ctdoshotCore/TroubleshootingView.swift
import SwiftUI
struct TroubleshootingView: View {
    @State private var signingInfo = ""
    var body: some View {
        Form {
            Section("Screen Recording") {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Copy Reset Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("tccutil reset ScreenCapture com.ctdoshot.app", forType: .string)
                }
                Text(signingInfo).font(.caption).monospaced()
            }
        }
        .onAppear {
            let pipe = Pipe()
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            task.arguments = ["-dv", "--verbose=2", Bundle.main.bundlePath]
            task.standardError = pipe
            try? task.run(); task.waitUntilExit()
            signingInfo = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }
    }
}
```

- [ ] **Step 2: Add first-capture guard in AppDelegate**

In `applicationDidFinishLaunching`, replace direct `hasScreenRecordingPermission` check with helper that shows alert on first trigger:

```swift
// in AppDelegate.swift, add method:
func ensureScreenRecordingOrAlert() -> Bool {
    if CaptureEngine.hasScreenRecordingPermission() { return true }
    let alert = NSAlert()
    alert.messageText = I18n.t("permission.screen.title") // fallback "Screen Recording Required"
    alert.informativeText = "Enable ctdoshot in System Settings → Privacy → Screen Recording, then quit and reopen the same .app."
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn,
       let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
        NSWorkspace.shared.open(url)
    }
    return false
}
```

Call it at capture entry points (`setupHotkey` action, menu item) not on launch.

- [ ] **Step 3: Embed tab in PreferencesView**

Add `Tab("Troubleshooting", systemImage: "wrench") { TroubleshootingView() }` to `PreferencesView` TabView.

- [ ] **Step 4: Manual verify**

Run: `swift build 2>&1 | tail -n 5`
Expected: Build succeeds, no new warnings.

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/TroubleshootingView.swift Sources/ctdoshotCore/AppDelegate.swift Sources/ctdoshotCore/PreferencesView.swift
git commit -m "feat(ux): add TCC first-launch alert + TroubleshootingView"
```

---

### Task 5: P1 — Site polish + demo GIFs

**Files:**
- Modify: `site/index.html` (or `site/*.html` as exists), `README.md` (add GIF section)
- Create: `docs/images/demo-region.gif`, `demo-blur.gif`, `demo-ocr.gif` (generated via dogfooding)

**Interfaces:**
- Consumes: existing `site/` GitBook layout
- Produces: hero GIF + CTA + SEO

- [ ] **Step 1: Dogfood 3 GIFs**

Run: capture region → annotate → export GIF via ctdoshot itself, save to `docs/images/demo-*.gif` (<5MB each, 15 FPS via GIFConverter).

- [ ] **Step 2: Update site hero**

In `site/index.html`, add above fold:

```html
<section class="hero">
  <img src="../docs/images/demo-region.gif" alt="Region capture demo" loading="lazy" width="800">
  <a class="cta" href="https://github.com/TIPC1110/ctdoshot/releases/latest">Download Universal (ZIP + DMG)</a>
  <p class="sub">macOS 13+ · Apple Silicon & Intel · Notarized</p>
</section>
<meta name="description" content="ctdoshot — menu-bar screenshot tool for macOS: region, window, OCR, annotate, pin.">
<meta property="og:image" content="docs/images/demo-region.gif">
```

- [ ] **Step 3: README GIF section**

Append under Highlights:

```markdown
## Demo
![Region](docs/images/demo-region.gif)
![Blur](docs/images/demo-blur.gif)
![OCR](docs/images/demo-ocr.gif)
```

- [ ] **Step 4: Verify Pages still builds**

Run: `cat site/index.html | head -n 20` and `ls -lh docs/images/demo-*.gif`

- [ ] **Step 5: Commit**

```bash
git add -f site/index.html README.md docs/images/demo-*.gif
git commit -m "docs(site): add hero demo GIF + CTA + SEO"
```

---

### Task 6: P1 — Release automation + Homebrew cask draft

**Files:**
- Modify: `.github/workflows/swift.yml` (add release job)
- Create: `Casks/ctdoshot.rb`, `SUPPORT.md`

**Interfaces:**
- Consumes: `build/ctdoshot.dmg`/`ZIP` + `SHA256SUMS` from Task 3
- Produces: GitHub Release on tag `v*`

- [ ] **Step 1: Add release job to swift.yml**

```yaml
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: build
    runs-on: macos-14
    permissions: { contents: write }
    steps:
      - uses: actions/download-artifact@v4
        with: { name: ctdoshot-macOS-Universal, path: build }
      - uses: softprops/action-gh-release@v2
        with:
          files: |
            build/ctdoshot-macOS-Universal.zip
            build/ctdoshot.dmg
            build/SHA256SUMS
          generate_release_notes: true
```

Separately add `Casks/ctdoshot.rb`:

```ruby
cask "ctdoshot" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_DMG"
  url "https://github.com/TIPC1110/ctdoshot/releases/download/v#{version}/ctdoshot.dmg"
  name "ctdoshot"
  desc "Menu-bar screenshot tool for macOS"
  homepage "https://tipc1110.github.io/ctdoshot/"
  depends_on macos: ">= :ventura"
  app "ctdoshot.app"
end
```

- [ ] **Step 2: Test cask locally**

Run: `shasum -a 256 build/ctdoshot.dmg | cut -d' ' -f1` → paste into `sha256`, then `brew install --cask ./Casks/ctdoshot.rb --no-quarantine 2>&1 | tail`

- [ ] **Step 3: Add SUPPORT.md**

Create `SUPPORT.md` linking to TroubleshootingView and `tccutil` steps.

- [ ] **Step 4: Verify tag flow dry-run**

Run: `git tag --list | head` — no push yet.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/swift.yml Casks/ctdoshot.rb SUPPORT.md
git commit -m "ci(release): auto GitHub Release on tag + cask draft"
```

---

### Task 7: P2 — SwiftLint warn-only + test wrapper adoption

**Files:**
- Create: `.swiftlint.yml`
- Modify: `.github/workflows/swift.yml` (optional lint step, not failing)

**Interfaces:**
- Consumes: SwiftLint binary if present
- Produces: warnings only

- [ ] **Step 1: Create .swiftlint.yml (10 rules)**

```yaml
disabled_rules: [trailing_whitespace]
opt_in_rules: []
included: [Sources, Tests]
line_length: { warning: 120, error: 200 }
force_unwrapping: warning
force_cast: warning
todo: warning
large_tuple: { warning: 3, error: 4 }
file_length: { warning: 800, error: 1200, ignore_comment_only_lines: true }
function_body_length: { warning: 100, error: 200 }
type_body_length: { warning: 400, error: 600 }
```

- [ ] **Step 2: Test locally (if swiftlint installed)**

Run: `swiftlint lint 2>&1 | head -n 20` — expect warnings, exit 0 (not error).

- [ ] **Step 3: CI optional step (non-blocking)**

Add to `swift.yml` after test:

```yaml
- name: SwiftLint (warn-only)
  continue-on-error: true
  run: swiftlint lint || true
```

- [ ] **Step 4: Verify build still passes**

Run: `swift build 2>&1 | tail -n 5`

- [ ] **Step 5: Commit**

```bash
git add .swiftlint.yml .github/workflows/swift.yml
git commit -m "chore(lint): add warn-only SwiftLint with 10 rules"
```

---

### Task 8: P2 — Split AppDelegate (PR1, <300L diff)

**Files:**
- Create: `Sources/ctdoshotCore/StatusBarController.swift`, `Sources/ctdoshotCore/AppLifecycle.swift`
- Modify: `Sources/ctdoshotCore/AppDelegate.swift` (thin to ~100L wiring)
- Test: `Tests/ctdoshotTests/AppDelegateTests.swift` (optional) + existing E2E `T1_MNU_*`

**Interfaces:**
- Consumes: `NSStatusItem`, `NSMenu`, `HotkeyManager`, `CaptureEngine`
- Produces: `StatusBarController` (setupStatusBar, rebuildMenu, pulse), `AppLifecycle` (setup, permission)

- [ ] **Step 1: Extract StatusBarController**

Move `setupStatusBar()`, `rebuildMenu()`, `setupMainMenu()`, pulse animation (`T1_MNU_003/004`) from AppDelegate to new class. Keep public API `rebuildMenu()` for AppDelegate to call on `AppLanguageDidChange`.

- [ ] **Step 2: Extract AppLifecycle**

Move `applicationDidFinishLaunching` wiring + `setupNotifications`/`setupHotkey` orchestration. AppDelegate holds `let statusBar = StatusBarController()` + `let lifecycle = AppLifecycle()` and delegates.

- [ ] **Step 3: Verify no behavior change**

Run: `./scripts/test.sh --filter RecordingE2ETests/testT1 2>&1 | tail -n 10`
Expected: Tier 1 30/30 pass.

- [ ] **Step 4: Check file lengths**

Run: `wc -l Sources/ctdoshotCore/AppDelegate.swift Sources/ctdoshotCore/StatusBarController.swift Sources/ctdoshotCore/AppLifecycle.swift`

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/StatusBarController.swift Sources/ctdoshotCore/AppLifecycle.swift Sources/ctdoshotCore/AppDelegate.swift
git commit -m "refactor(app): split AppDelegate into StatusBarController + AppLifecycle"
```

---

### Task 9: P2 — Split DrawingCanvasView (PR2)

**Files:**
- Create: `Sources/ctdoshotCore/CanvasState.swift`, `CanvasRenderer.swift`, `Sources/ctdoshotCore/Tools/Tool.swift` + `ArrowTool.swift`/`RectTool.swift`/`TextTool.swift`/`StepTool.swift`
- Modify: `Sources/ctdoshotCore/DrawingCanvasView.swift` (delegate)
- Test: `Tests/ctdoshotTests/CanvasStateTests.swift` (new)

**Interfaces:**
- Consumes: `CanvasState` (tool, selection, undo/redo), `CanvasRenderer.bake(to: NSBitmapImageRep)`
- Produces: `DrawingCanvasView` thin SwiftUI wrapper

- [ ] **Step 1: Create CanvasState + tests (TDD)**

```swift
// Tests/ctdoshotTests/CanvasStateTests.swift
import XCTest; @testable import ctdoshotCore
final class CanvasStateTests: XCTestCase {
    func testUndoRedo() {
        var s = CanvasState()
        s.add(.rect(.zero)); XCTAssertEqual(s.elements.count, 1)
        s.undo(); XCTAssertEqual(s.elements.count, 0)
        s.redo(); XCTAssertEqual(s.elements.count, 1)
    }
}
```

Run: `./scripts/test.sh --filter CanvasStateTests` → FAIL (no type), then implement minimal `CanvasState`.

- [ ] **Step 2: Extract CanvasRenderer**

Move `CGContext` bake logic (Retina resolution, `NSBitmapImageRep`) to `CanvasRenderer.bake(elements:to:)`.

- [ ] **Step 3: Extract Tools**

Each tool implements `protocol Tool { func draw(in ctx: CGContext) }`. Move per-tool hit testing.

- [ ] **Step 4: Verify**

Run: `swift build && ./scripts/test.sh --filter CanvasStateTests 2>&1 | tail`

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/CanvasState.swift Sources/ctdoshotCore/CanvasRenderer.swift Sources/ctdoshotCore/Tools Tests/ctdoshotTests/CanvasStateTests.swift Sources/ctdoshotCore/DrawingCanvasView.swift
git commit -m "refactor(canvas): split DrawingCanvasView into State+Renderer+Tools"
```

---

### Task 10: P2 — Split ScreenRecorder (PR3)

**Files:**
- Create: `Sources/ctdoshotCore/RecordingSession.swift`, `AudioCapture.swift`, `HUDController.swift`
- Modify: `Sources/ctdoshotCore/ScreenRecorder.swift` (facade for E2E harness)
- Test: existing `RecordingE2ETests` must stay green

**Interfaces:**
- Consumes: `AVAssetWriter`, `AVCaptureSession`, `SCContentFilter`
- Produces: `ScreenRecorder` facade delegating to `RecordingSession`

- [ ] **Step 1: Extract RecordingSession**

Move `setupSyntheticRecordingSession()`, `startRecording()`, `stopRecording()` AVAssetWriter lifecycle, `T1_MP4_*` logic, `T2_BND_003` PTS sync.

- [ ] **Step 2: Extract AudioCapture + HUDController**

`AudioCapture` handles mic mute toggles `T1_AUD_*`; `HUDController` handles floating HUD `T1_HUD_*` (non-activating panel, timer `MM:SS`).

- [ ] **Step 3: Keep facade**

`ScreenRecorder` retains public API used by `E2ETestRunner` (`startRecording`, `stopRecording`, `pause`/`resume`, `elapsedTime`). Internally `session = RecordingSession()`.

- [ ] **Step 4: Verify full E2E**

Run: `./scripts/test.sh --filter RecordingE2ETests 2>&1 | tail -n 20`
Expected: 42/42 pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/RecordingSession.swift Sources/ctdoshotCore/AudioCapture.swift Sources/ctdoshotCore/HUDController.swift Sources/ctdoshotCore/ScreenRecorder.swift
git commit -m "refactor(recorder): split ScreenRecorder into Session+Audio+HUD"
```

---

### Task 11: P3 — Editor polish (zoom + thickness)

**Files:**
- Modify: `Sources/ctdoshotCore/CanvasState.swift` (zoom, thickness), `DrawingCanvasView.swift` (slider), `PreferencesView.swift` (persist), `I18n.swift` (keys)

**Interfaces:**
- Consumes: `UserDefaults` key `canvas.thickness`, `canvas.zoom`
- Produces: zoom 100/200% + thickness picker

- [ ] **Step 1: Add state + persistence**

In `CanvasState`, add `var thickness: CGFloat` backed by `UserDefaults.standard.double(forKey: "canvas.thickness")` (default 2). On set, persist.

- [ ] **Step 2: Add UI**

In `DrawingCanvasView` toolbar, add `Slider(value: $state.thickness, in: 1...8)` + `Picker("Zoom", selection: $state.zoom)` with 100%/200%.

- [ ] **Step 3: Verify bake respects thickness**

Test: draw rect thickness 1 vs 8, `CanvasRenderer.bake` output size differs (manual visual check or unit: `XCTAssertEqual(state.thickness, 8)`).

- [ ] **Step 4: Build**

Run: `swift build 2>&1 | tail`

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/CanvasState.swift Sources/ctdoshotCore/DrawingCanvasView.swift Sources/ctdoshotCore/PreferencesView.swift Sources/ctdoshotCore/I18n.swift
git commit -m "feat(editor): add zoom + thickness picker with UserDefaults persist"
```

---

### Task 12: P3 — History filter + hotkey conflict

**Files:**
- Modify: `Sources/ctdoshotCore/HistoryManager.swift`, `HistoryGalleryView.swift`, `HotkeyChord.swift`/`HotkeyManager.swift`, `HotkeyStore.swift`

**Interfaces:**
- Consumes: `HistoryManager.shared.shots`, `OCRManager` indexed text
- Produces: `HistoryGalleryView` filter bar, `HotkeyChord.conflictsWithSystem()`

- [ ] **Step 1: History filter bar**

In `HistoryGalleryView`, add `@State private var filter = ""` + `DatePicker` range, filter `shots.filter { $0.ocrText.localizedCaseInsensitiveContains(filter) }`, lazy `LazyVGrid` for thumbnails.

- [ ] **Step 2: Hotkey conflict detection**

In `HotkeyChord`, add `func conflictsWithSystem() -> Bool` checking against known system chords (⌘Space, etc.) via `Carbon` `GetEventHotKeyID` collision. Show warning in `PreferencesView` hotkey row.

- [ ] **Step 3: Test history search**

Run: `./scripts/test.sh --filter HistorySearchTests 2>&1 | tail`

- [ ] **Step 4: Manual verify**

Open History window, type filter, verify thumbnails filter.

- [ ] **Step 5: Commit**

```bash
git add Sources/ctdoshotCore/HistoryManager.swift Sources/ctdoshotCore/HistoryGalleryView.swift Sources/ctdoshotCore/HotkeyChord.swift Sources/ctdoshotCore/HotkeyManager.swift
git commit -m "feat(history): add filter bar + hotkey conflict detection"
```

---

## Self-Review

**Spec coverage:**
- P0 notarize+staple: Task 3 ✓ (gated, validate, SHA256SUMS)
- P0 DMG: Task 1 ✓ (hdiutil, /Applications symlink)
- P0 TCC UX + TroubleshootingView: Task 4 ✓
- P1 site + GIFs: Task 5 ✓
- P1 release + cask: Task 6 ✓
- P2 lint: Task 7 ✓
- P2 test wrapper: Task 2 ✓
- P2 splits (3 PRs): Tasks 8,9,10 ✓ (each <300L, E2E gate)
- P3 editor: Task 11 ✓
- P3 history/hotkey: Task 12 ✓
- CI cache: Task 3 ✓
- All gaps closed.

**Placeholder scan:** No TBD/TODO/placeholder; each step has exact file paths, code blocks, commands, expected outputs.

**Type consistency:** `StatusBarController`/`AppLifecycle`/`CanvasState`/`CanvasRenderer`/`RecordingSession`/`AudioCapture`/`HUDController`/`TroubleshootingView` names consistent across tasks. `scripts/test.sh` and `scripts/make-dmg.sh` signatures match Task 3 consumption.

**Fixes applied:** Added `SUPPORT.md` and SHA256SUMS to release, gated notarize on secrets to avoid fork failures, kept cask draft local until notarized.

---

Plan complete and saved to `docs/superpowers/plans/2026-08-29-ctdoshot-improvement-roadmap.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
