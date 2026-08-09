# Open-Source macOS Release Checklist

### Core
* [x] `.app` bundle
* [x] `Info.plist`
* [x] Bundle ID
* [x] Version
* [x] App icon
* [x] Light/Dark Mode
* [x] Resize
* [x] Retina/4K
* [x] Menu
* [x] Settings

### Security
* [x] Code Signing
* [x] Hardened Runtime
* [ ] App Sandbox — *nếu cần*
* [ ] Keychain — *nếu cần*
* [ ] HTTPS — *nếu app online*

### Compatibility
* [x] Apple Silicon
* [ ] Intel — *nếu tuyên bố hỗ trợ*
* [ ] Universal Binary — *nếu hỗ trợ cả hai*

### Quality
* [x] Error handling
* [x] Logging
* [x] Performance
* [x] Accessibility cơ bản
* [x] Persistence
* [x] Automated tests

### Distribution
* [x] GitHub repository
* [x] README
* [x] LICENSE
* [x] Installation guide
* [x] Release build
* [ ] Notarization
* [ ] DMG

### Updates
* [ ] Manual update — *đủ*
* [ ] Auto update — *nếu muốn*

### Privacy
* [x] Không thu thập dữ liệu không cần thiết
* [x] Không hard-code secret
* [x] Không log sensitive data

### Testing
* [x] Fresh install
* [x] Upgrade
* [x] Uninstall
* [x] Apple Silicon
* [x] Dark Mode
* [x] 4K
* [x] Permission denied
* [ ] Offline — *nếu app online*

---

**Mục tiêu Open-Source macOS App:**
`Build → Sign → Test → GitHub Release → User cài được → App chạy ổn`
