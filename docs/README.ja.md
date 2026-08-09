# ctdoshot

**パワーユーザー向けの、高速でネイティブな macOS スクリーンショットツール。**

メニューバーから撮影 → 注釈 → コピー/保存。ScreenCaptureKit・SwiftUI・Vision 製。Shottr / ShareX 系のワークフローに近く、macOS 向けに最適化。

**By [ctdoteam](https://github.com/TIPC1110)** · [GitHub](https://github.com/TIPC1110/ctdoshot)

**言語:** [English](README.en.md) · [Tiếng Việt](README.vi.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [メイン README](../README.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://github.com/TIPC1110/ctdoshot)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)

---

## 主な機能

| 領域 | 内容 |
|------|------|
| **撮影** | 範囲、全画面、アクティブウィンドウ、前回の範囲、スクロール結合 |
| **エディタ** | 矢印、テキスト、番号、矩形、フリーハンド、**クロップ**、**モザイクぼかし**、元に戻す/やり直し |
| **書き出し** | クリップボード（⌃C / ⌘C）、PNG/JPEG 保存、パスもペーストボード、画面にピン留め |
| **OCR** | Vision 文字認識（英/越/日）、OCR テキストで履歴検索 |
| **ワークフロー** | 撮影後の 表示 / コピー / 保存、Esc 動作、再割り当て可能なグローバルホットキー |
| **i18n** | UI は English + ベトナム語 |

Bundle ID: `com.ctdoshot.app` · メニューバーアプリ（`LSUIElement`）

---

## 動作環境

- **macOS 13** 以降  
- **画面収録** の許可（システム設定 → プライバシーとセキュリティ）  
- **Xcode 15+**（フル Xcode）でビルドとテスト  
- Swift 5.9+

> Command Line Tools のみでも `swift build` は可能な場合があります。**`swift test` にはフル Xcode が必要**です。

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## インストール（ソースから）

```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot
./scripts/package-app.sh
open build/ctdoshot.app
```

### 初回起動 — 画面収録

1. **システム設定 → プライバシーとセキュリティ → 画面収録** を開く  
2. **ctdoshot** をオン  
3. **完全終了**（⌘Q）してから `build/ctdoshot.app` を再度開く  

撮影テストは必ず **パッケージ済み `.app`** で行ってください。`swift run` や `.build/` 直下のバイナリは **別の TCC 身元** になります。

再ビルド後に許可ダイアログが繰り返す場合:

```bash
tccutil reset ScreenCapture com.ctdoshot.app
open build/ctdoshot.app
```

---

## 使い方

ctdoshot は **メニューバー**（カメラ / ビューファインダーアイコン）に常駐します。

### 撮影

| 操作 | デフォルトホットキー |
|------|----------------------|
| 範囲撮影 | ⇧⌘S |
| 画面全体 | ⇧⌘3 |
| アクティブウィンドウ | ⇧⌘W |
| 前回の範囲 | ⇧⌘L |
| スクロール撮影 | ⌥⇧⌘X |
| クイック OCR（範囲 → テキスト） | ⌃⌥⌘O |
| 履歴 | ⇧⌘H |

**環境設定 → ホットキー** で行をクリックし、新しい組み合わせを録音できます。

### エディタ

- 描画: 矢印、矩形、ペン、ステップ番号、テキスト  
- **クロップ** と **ぼかし / モザイク**  
- **⌃C** / **⌘C** — 注釈付き画像をコピー  
- **⌘S** / 保存してコピー — ファイル保存（コピー有効時はパスも）  
- **⌘Z** / **⇧⌘Z** — 元に戻す / やり直し  
- Esc — 任意でコピー/保存して閉じる（環境設定 → 詳細）

### 環境設定

言語、保存フォルダ/形式、撮影後の動作、OCR、ログイン時起動、グローバルホットキー録音。

---

## 開発

```bash
swift build
swift build -c release
./scripts/package-app.sh    # → build/ctdoshot.app
swift test
```

```
Sources/
  ctdoshotApp/          # @main エントリ
  ctdoshotCore/         # 撮影・編集・OCR・ホットキー・UI
Tests/ctdoshotTests/
packaging/
scripts/package-app.sh
```

- **撮影:** ScreenCaptureKit + 範囲オーバーレイ  
- **注釈:** ベクター、書き出し時に CG で焼き込み  
- **OCR:** Vision  
- **ホットキー:** Carbon + `HotkeyStore`  

---

## コントリビュート

1. フォークしてブランチを作成（`feature/…` / `fix/…`）  
2. `swift test` を実行  
3. 画面収録まわりはパッケージ `.app` で確認  
4. `main` へ Pull Request  

不具合報告には: macOS バージョン、起動方法（`.app` か `swift run`）、画面収録の有無を書いてください。

---

## プライバシー

ctdoshot は **ローカル**で動作します。スクリーンショットと OCR は、あなたがコピー・保存・共有しない限り Mac 上に留まります。画面収録は、あなたが要求した撮影にのみ使われます。

---

## ライセンス

MIT © **ctdoteam** — [LICENSE](../LICENSE) を参照。

---

## リンク

- リポジトリ: https://github.com/TIPC1110/ctdoshot  
- Issues: https://github.com/TIPC1110/ctdoshot/issues  
- チーム: **ctdoteam**
