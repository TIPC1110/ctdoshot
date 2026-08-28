# ctdoshot Improvement Roadmap — Design Spec

**Date:** 2026-08-29
**Status:** Approved (brainstorming 5/5 slices)
**Author:** Sisyphus (with user, solo, low-hours constraint)
**Priority order:** A (install friction) > D (visibility) > C (maintainability) > B (retention)
**Principle:** Phased, shippable increments. Each phase merges green before next. No big-bang refactor.

---

## 1. Context & Constraints

- **App:** ctdoshot — menu-bar screenshot tool, macOS 13+, SPM (ctdoshotCore + ctdoshotApp), Bundle ID `com.ctdoshot.app`, `LSUIElement`. Swift 5.9 tools / Swift 6.1 runtime. No Xcode project.
- **Codebase:** ~5k LOC core. Largest files: `AppDelegate.swift` ~692L, `DrawingCanvasView.swift` ~883L, `ScreenRecorder.swift` ~885L, `CaptureEngine.swift` 525L. 42 E2E tests (Tier 1:30, T2:5, T3:4, T4:3) via `E2ETestRunner` + `E2EVerifier` (async/await, synthetic BGRA/AAC, isolated `/tmp/ctdoshot_e2e_<UUID>`). `swift build` works with CLT; `swift test` requires full Xcode (`DEVELOPER_DIR` workaround needed).
- **Current state:** Universal binary done, TCC stable cert (`ctdoshot Developer`) via `ensure-signing-identity.sh`/`package-app.sh`, GitHub Pages GitBook site, CI `swift.yml` (build+test+universal package), Releases manual, no notarization/DMG, site without demo GIF, lint/format absent, God-files intact.
- **Constraints:** Solo dev, limited hours/week. Must favor low-touch high-impact (YAGNI). High product quality desired but must not block P0/P1.
- **Sources:** `README.md`, `Package.swift`, `TEST_INFRA.md`, `work.md`, `scripts/package-app.sh`, `packaging/Info.plist`, `.github/workflows/swift.yml|pages.yml`, git log.

---

## 2. Goals & Non-Goals

**Goals:**
- P0: New user installs DMG/ZIP and passes Gatekeeper + Screen Recording in one attempt.
- P1: Discoverability — site CTA + demo, releases auto-visible.
- P2: Solo maintainability — God-files split incrementally, CI fast, lint warn-only.
- P3: Retention polish — editor/history small delights.

**Non-Goals (explicitly deferred):**
- Sparkle auto-update, pkg installer, video/GIF recording feature, upload plugins, TCA/MVVM rewrite, full SwiftLint strict fail, Product Hunt launch, new i18n languages.

---

## 3. Architecture Overview

Keep current SPM + `LSUIElement` + ScreenCaptureKit + AVAssetWriter pipeline. No framework change.

```
Before: AppDelegate (692L god) ──direct──▶ CaptureEngine, DrawingCanvasView, ScreenRecorder
After (incremental):
  AppDelegate (thin wiring)
    ├─ StatusBarController (NSStatusItem, menus, pulse)
    ├─ AppLifecycle (delegate, permissions gating)
    ├─ CaptureEngine (unchanged)
    ├─ CanvasState + CanvasRenderer + Tools/ (from DrawingCanvasView)
    └─ RecordingSession + AudioCapture + HUDController (from ScreenRecorder)

CI: build → test → package --universal → notarize+staple (CI only) → make-dmg → upload ZIP+DMG
Site: static `site/` + Releases feed + GIF demos
Prefs: TroubleshootingView for TCC
```

---

## 4. Phased Design

### Phase P0 — Distribution & Onboarding (Priority A) — ~1 week

**Problem:** Gatekeeper warning on unsigned ZIP, TCC re-prompt confusion, first-launch dead end.

**Solution:**
- **Notarization:** Extend `scripts/package-app.sh` with `--notarize` (CI-only). CI `swift.yml` adds steps:
  ```yaml
  - run: xcrun notarytool submit build/ctdoshot.app --wait --apple-id ${{ secrets.APPLE_ID }} --password ${{ secrets.APPLE_APP_PASSWORD }} --team-id ${{ secrets.APPLE_TEAM_ID }}
  - run: xcrun stapler staple build/ctdoshot.app
  ```
  Stapled app then `ditto -ck` to ZIP. Secrets: `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`. Local dev still uses stable cert or ad-hoc (no secret needed).
- **DMG:** New `scripts/make-dmg.sh` using `hdiutil` only (no extra deps). Creates `build/ctdoshot.dmg` with `/Applications` symlink and minimal background. CI uploads both ZIP and DMG.
- **First-launch UX:** On first capture trigger, check `CGPreflightScreenCaptureAccess()`; if denied, show localized `NSAlert` with 3 steps + button `Open System Settings` via `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`. Do not poll on every launch.
- **TroubleshootingView:** New SwiftUI view in `PreferencesView` → tab "Screen Recording" shows current signing identity (`codesign -dv`) + status (ad-hoc vs stable cert) + copyable `tccutil reset ScreenCapture com.ctdoshot.app` command. Reduces support tickets.
- **Docs:** README first-launch adds 10s GIF, explicit "use notarized .app, not swift run/.build binary".

**Success criteria:** CI artifact ZIP/DMG stapled; Gatekeeper passes on macOS 13-15 clean VM; TCC flow completes without manual `tccutil`.

**Risks:** Notarization secrets missing on forks — guard with `if: secrets.APPLE_ID != ''`; fallback to unsigned artifact.

### Phase P1 — Visibility & Growth (Priority D) — ~1 week after P0

**Solution:**
- **Site polish:** `site/` — add hero GIF demo (region → annotate → ⌘C), 6-feature grid, arch-aware download CTA (detect arm64/x86_64), embed latest Release notes, SEO title/desc + OG image. No full redesign.
- **Release automation:** `swift.yml` on `push: tags: v*` runs `softprops/action-gh-release@v2` attaching `ctdoshot.dmg`, `ctdoshot-macOS-Universal.zip`, `SHA256SUMS`. Notes generated from `git log --pretty`.
- **Homebrew cask draft:** Local `Casks/ctdoshot.rb` tested via `brew install --cask ./Casks/ctdoshot.rb` (points to GitHub Release URL, `sha256`, `depends_on macos: ">= :ventura"`). README documents `brew tap ctdoteam/tap` but do not submit to homebrew-cask until after notarization verified.
- **Demo GIFs:** Dogfood ctdoshot to record 3 GIFs <5MB each (`docs/images/demo-*.gif`): region capture, blur/pixelate, OCR to clipboard.

**Success criteria:** Site has clear CTA + GIF; `git tag v1.x` creates Release with both artifacts; cask installs locally.

### Phase P2 — Maintainability (Priority C) — Interleaved, 1 PR at a time, ~3-4 weeks total

**Solution (incremental, each PR <300L diff, tests green):**
- **PR1 — AppDelegate split:** Extract `StatusBarController.swift` (NSStatusItem, menu building, icon pulse `T1_MNU_003/004`) and `AppLifecycle.swift` (NSApplicationDelegate, permission gating, `UNUserNotificationCenterDelegate`). `AppDelegate` becomes ~100L wiring.
- **PR2 — DrawingCanvasView split:** Extract `CanvasState.swift` (tool enum, selection, undo/redo stack), `CanvasRenderer.swift` (CGContext bake on `NSBitmapImageRep`, Retina handling), `Tools/ArrowTool.swift`, `RectTool.swift`, `TextTool.swift`, `StepTool.swift`. Add unit test for `CanvasState` undo/redo (currently untested).
- **PR3 — ScreenRecorder split:** Extract `RecordingSession.swift` (AVAssetWriter lifecycle, `setupSyntheticRecordingSession`), `AudioCapture.swift` (AVCaptureSession mic), `HUDController.swift` (floating HUD, timer `MM:SS`, mic toggle). Keep `ScreenRecorder` as facade for E2E harness.
- **Lint/format light:** Add `.swiftlint.yml` with 10 rules only (`line_length:120`, `force_unwrapping`, `force_cast`, `todo`, `large_tuple`, etc.) in `warning` mode. CI does not fail on lint; local `swiftlint lint` optional. No auto-format on repo.
- **Test wrapper:** New `scripts/test.sh` auto-detects `xcode-select -p`; if CLT, exports `DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer` before `xcrun --sdk macosx swift test`. CI caches `~/.build` and `~/.swiftpm`. Add isolated `CanvasStateTests.swift`.

**Success criteria:** 3 PRs merged, no behavior change, E2E 42 still green, `scripts/test.sh` works on both CLT and Xcode machines, lint warn-only.

### Phase P3 — Retention Polish (Priority B) — After P0/P1, when time allows

**Solution:**
- **Editor:** Add zoom 100/200% + slider, thickness picker (persisted via `UserDefaults`, addresses Issue #1), nudge with arrow keys already partially there.
- **History:** `HistoryManager` JSON + OCR text → add filter bar (text search + date), thumbnail lazy load via `NSImage` cache. No DB migration.
- **Hotkeys:** `HotkeyChord` conflict detection (check against system shortcuts via Carbon), versioned migration for `HotkeyStore`.

**Success criteria:** Editor zoom + thickness shipped, history filter usable.

---

## 5. Data Flow & Key Interactions

- **Capture flow:** Hotkey/Menu → `StatusBarController` → `CaptureEngine` (SCKit content filter, HUD exclusion `T1_HUD_002`) → `ScreenRecorder` (AVAssetWriter BGRA + optional AAC) → `OutputManager` (save PNG/JPEG, pasteboard) → `HistoryManager.shared.addShot` + `NSPasteboard.general.setString` → `E2EVerifier` (async track inspection).
- **Notarization flow:** `swift build --universal` → `codesign` (stable cert) → `notarytool submit --wait` → `stapler staple` → `ditto` ZIP/DMG → `gh-release`.
- **TCC flow:** Capture trigger → `CGPreflightScreenCaptureAccess` → if denied → `NSAlert` → open System Settings → user grants → quit/reopen same .app.

---

## 6. Error Handling

- **Notarization failure:** CI step `continue-on-error: false` but guarded by secret existence; on failure upload unsigned artifact with `notarization: skipped` note. Local `package-app.sh --notarize` without secrets prints warning and falls back to staple-skip.
- **DMG creation failure:** `make-dmg.sh` exits non-zero; CI fails fast (no partial Release).
- **TCC denied:** Graceful fallback `ScreenRecorder` returns `permissionDenied` error, HUD shows retry button, no crash. `T2_BND_004` E2E covers this.
- **Invalid save dir:** `T2_BND_005` — `OutputManager` falls back to `~/Pictures/ctdoshot` and shows alert.
- **Lint missing:** `scripts/test.sh` does not require `swiftlint` installed.

---

## 7. Testing Strategy

- **Keep existing 42 E2E** as gate (must 100% pass). Run via `scripts/test.sh` (Tier 1..4 filters as before).
- **New tests:** `CanvasStateTests` (undo/redo, tool selection), `StatusBarControllerTests` (menu item disabling `T1_MNU_005` via unit, not E2E), `TroubleshootingView` snapshot not needed.
- **CI gate:** `swift build -v` → `scripts/test.sh` → `package --universal` → `make-dmg` (no need to notarize on PRs, only on `main`/`tags`).
- **Manual QA:** Gatekeeper on clean macOS 13/14/15 VM for DMG/ZIP; TCC first-launch on fresh user account.

---

## 8. Rollout Plan

1. Week 1 (P0): `make-dmg.sh` + `TroubleshootingView` + first-launch alert + notarization CI (secrets). Tag `v1.0.1-rc1` to test notarization without publishing.
2. Week 2 (P1): Site polish + GIFs + release automation + cask draft. Tag `v1.1.0` with DMG+ZIP.
3. Weeks 3-6 (P2): One split PR per week, each behind `main` with CI green. Lint added after PR1.
4. When time (P3): Editor/history polish.

Each phase is independently shippable; no phase blocks the previous one's release.

---

## 9. Open Questions Resolved

- Q: Solo low-hours → handled via phased, <300L PRs, warn-only lint.
- Q: Plan detail vs quality → this spec is the detailed design; implementation plan (writing-plans) will break each phase into atomic tasks with file-level checklists.
- Q: Windows port `win/` → explicitly out of scope for this roadmap; keep scaffold but no work until macOS P0/P1 done.

---

## 10. References

- `README.md`, `TEST_INFRA.md`, `work.md`, `checklist.md`
- `Package.swift` (swift-tools-version 5.9, macOS 13)
- `Sources/ctdoshotCore/AppDelegate.swift`, `DrawingCanvasView.swift`, `ScreenRecorder.swift`
- `Tests/ctdoshotTests/E2ETestRunner.swift`, `RecordingE2ETests.swift`
- `scripts/package-app.sh`, `scripts/ensure-signing-identity.sh`, `packaging/Info.plist`
- `.github/workflows/swift.yml`, `pages.yml`, `site/`, `docs/wiki/`
