# ctdoshot

macOS 菜单栏截图工具：截图、标注、复制/保存。

**出品：[ctdoteam](https://github.com/TIPC1110)** · [GitHub](https://github.com/TIPC1110/ctdoshot)

**语言：** [English](README.en.md) · [Tiếng Việt](README.vi.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [主 README](../README.md)

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://github.com/TIPC1110/ctdoshot)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://www.swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)

---

## 功能亮点

| 模块 | 能力 |
|------|------|
| **截图** | 区域、全屏、活动窗口、上次区域、滚动长图拼接 |
| **编辑** | 箭头、文字、序号、矩形、手绘、**裁剪**、**马赛克模糊**、撤销/重做 |
| **导出** | 剪贴板（⌃C / ⌘C）、保存 PNG/JPEG、路径写入剪贴板、钉在屏幕上 |
| **OCR** | Vision 识别（英/越/日），按 OCR 文字搜索历史 |
| **工作流** | 截图后：显示 / 复制 / 保存；Esc 行为；可录制的全局快捷键 |
| **本地化** | 界面支持 English + 越南语 |

Bundle ID：`com.ctdoshot.app` · 菜单栏应用（`LSUIElement`）

---

## 系统要求

- **macOS 13** 或更高  
- **屏幕录制**权限（系统设置 → 隐私与安全性）  
- **Xcode 15+**（完整 Xcode）用于构建与单元测试  
- Swift 5.9+

> 仅 Command Line Tools 时 `swift build` 可能可用。**`swift test` 需要完整 Xcode**。

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 安装（从源码）

```bash
git clone https://github.com/TIPC1110/ctdoshot.git
cd ctdoshot
./scripts/package-app.sh
open build/ctdoshot.app
```

### 首次启动 — 屏幕录制权限

1. 打开 **系统设置 → 隐私与安全性 → 屏幕录制**  
2. 启用 **ctdoshot**  
3. **完全退出**（⌘Q）后重新打开 `build/ctdoshot.app`  

请始终使用 **打包后的 `.app`** 进行截图。`swift run` 或 `.build/` 下的二进制对应 **不同的 TCC 身份**。

若重建后反复弹出权限请求：

```bash
tccutil reset ScreenCapture com.ctdoshot.app
open build/ctdoshot.app
```

---

## 使用说明

ctdoshot 位于 **菜单栏**（取景器/相机图标）。

### 截图

| 操作 | 默认快捷键 |
|------|------------|
| 区域截图 | ⇧⌘S |
| 全屏截图 | ⇧⌘3 |
| 活动窗口 | ⇧⌘W |
| 上次区域 | ⇧⌘L |
| 滚动截图 | ⌥⇧⌘X |
| 快速 OCR（区域 → 文本剪贴板） | ⌃⌥⌘O |
| 历史记录 | ⇧⌘H |

可在 **偏好设置 → 快捷键** 中点击行并录制新组合键。

### 编辑器

- 绘制：箭头、矩形、画笔、序号、文字  
- **裁剪** 与 **模糊/马赛克**  
- **⌃C** / **⌘C** — 复制带标注的图片  
- **⌘S** / 保存并复制 — 保存文件（开启复制时同时提供路径）  
- **⌘Z** / **⇧⌘Z** — 撤销 / 重做  
- Esc — 可选复制/保存后关闭（偏好设置 → 高级）

### 偏好设置

语言、保存目录与格式、截图后动作、OCR、登录时启动、全局快捷键录制。

---

## 开发

```bash
swift build
swift build -c release
./scripts/package-app.sh    # → build/ctdoshot.app
swift test
```

```
Sources/
  ctdoshotApp/          # @main 入口
  ctdoshotCore/         # 截图、编辑、OCR、快捷键、UI
Tests/ctdoshotTests/
packaging/
scripts/package-app.sh
```

- **截图：** ScreenCaptureKit + 区域遮罩  
- **标注：** 矢量工具，导出时 CG 烘焙  
- **OCR：** Vision  
- **快捷键：** Carbon + `HotkeyStore`  

---

## 贡献

1. Fork 并创建分支（`feature/…` / `fix/…`）  
2. 运行 `swift test`  
3. 截图相关请用打包 `.app` 测试  
4. 向 `main` 提交 Pull Request  

反馈问题时请注明：macOS 版本、启动方式（`.app` 或 `swift run`）、屏幕录制是否已开启。

---

## 隐私

ctdoshot **仅在本地运行**。截图与 OCR 结果保存在你的 Mac 上，除非你自行复制、保存或分享。屏幕录制仅用于你主动发起的截图。

---

## 许可证

MIT © **ctdoteam** — 见 [LICENSE](../LICENSE)。

---

## 链接

- 仓库：https://github.com/TIPC1110/ctdoshot  
- Issues：https://github.com/TIPC1110/ctdoshot/issues  
- 团队：**ctdoteam**  

---

<p align="center">
  <sub>黄沙群岛和长沙群岛是越南领土。</sub>
</p>
