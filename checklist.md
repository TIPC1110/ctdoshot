## Checklist ứng dụng macOS — FULL

### 1. Cấu trúc app

* [x] App có `.app` bundle chuẩn
* [x] `Info.plist`
* [x] `CFBundleIdentifier` duy nhất
* [x] `CFBundleName`
* [x] `CFBundleDisplayName`
* [x] `CFBundleVersion`
* [x] `CFBundleShortVersionString`
* [ ] App icon `.icns`
* [ ] `Assets.xcassets`
* [x] App có entry point rõ ràng
* [x] Bundle Resources chứa đúng file
* [x] Không phụ thuộc file nằm ngoài bundle nếu không cần

### 2. Giao diện macOS

* [x] Native macOS UI
* [x] Hỗ trợ Light Mode
* [x] Hỗ trợ Dark Mode
* [x] Dynamic system colors
* [x] Font hệ thống
* [x] Toolbar chuẩn macOS
* [ ] Sidebar nếu app cần navigation
* [x] Menu bar
* [ ] Context menu
* [x] Tooltip
* [x] Dialog / Alert
* [x] Sheet
* [x] Progress indicator
* [x] Empty state
* [x] Loading state
* [x] Error state
* [x] Success state
* [x] Keyboard focus rõ ràng
* [x] Không hard-code kích thước UI
* [x] Hỗ trợ resize cửa sổ
* [x] Hỗ trợ fullscreen
* [x] Hỗ trợ nhiều màn hình
* [x] UI scale tốt với Retina
* [x] UI không vỡ ở màn hình 4K/5K

### 3. Window

* [x] Window title
* [x] Minimize
* [x] Maximize / Zoom
* [x] Close
* [x] Resize
* [ ] Remember window position
* [ ] Remember window size
* [ ] Restore window state
* [x] Multiple windows nếu cần
* [x] Window behavior đúng khi app inactive
* [x] Fullscreen
* [x] Spaces / Mission Control hoạt động đúng

### 4. Menu Bar

* [x] App menu
* [ ] About
* [x] Preferences / Settings
* [ ] Services nếu cần
* [ ] Hide App
* [ ] Hide Others
* [x] Quit
* [ ] File menu nếu cần
* [ ] Edit menu
* [ ] View menu
* [ ] Window menu
* [ ] Help menu
* [x] Keyboard shortcut cho action quan trọng
* [x] Menu item enable/disable đúng trạng thái

### 5. Keyboard

* [x] `⌘ + Q` Quit
* [x] `⌘ + W` Close window
* [x] `⌘ + ,` Settings
* [x] `⌘ + C` Copy
* [ ] `⌘ + V` Paste
* [ ] `⌘ + X` Cut nếu cần
* [x] `⌘ + Z` Undo
* [x] `⇧ + ⌘ + Z` Redo
* [ ] `⌘ + A` Select All
* [x] Shortcut cho chức năng chính
* [x] Tab navigation
* [ ] Arrow navigation
* [x] Enter / Return
* [x] Escape
* [x] Keyboard-only workflow

### 6. Settings

* [x] General
* [x] Appearance
* [x] Behavior
* [x] Notifications nếu cần
* [x] Privacy
* [ ] Account nếu có login
* [x] Storage / Cache
* [ ] Network
* [x] Keyboard shortcuts
* [ ] Reset settings
* [ ] Restore defaults
* [x] Settings persistence

### 7. File system

Nếu app thao tác file:

* [ ] Open file
* [x] Save
* [x] Save As
* [ ] Import
* [x] Export
* [ ] Drag & drop
* [x] File picker
* [x] Folder picker
* [x] Recent files
* [x] File permission handling
* [x] Missing file handling
* [x] Invalid file handling
* [x] Read-only file handling
* [x] Large file handling
* [x] Auto-save nếu cần
* [ ] Recovery sau crash
* [ ] Security-scoped bookmarks nếu cần sandbox

### 8. macOS permissions

Xác định app cần quyền gì:

* [ ] Camera
* [ ] Microphone
* [x] Screen Recording
* [ ] Accessibility
* [x] Files and Folders
* [ ] Photos
* [ ] Contacts
* [ ] Location
* [ ] Bluetooth
* [x] Notifications
* [ ] Removable Volumes
* [ ] Full Disk Access nếu thực sự cần
* [x] Chỉ request quyền khi cần
* [x] Có `Info.plist` usage description tương ứng
* [x] Xử lý trường hợp user từ chối
* [x] Không crash khi permission bị revoke
* [x] Giải thích rõ tại sao cần permission

### 9. Security

* [ ] App Sandbox nếu phù hợp
* [x] Hardened Runtime
* [x] Code Signing
* [ ] Developer ID
* [ ] Notarization
* [ ] HTTPS
* [x] Không lưu password plaintext
* [ ] Keychain cho credentials
* [x] Không hard-code API key
* [x] Không hard-code secret
* [x] Validate input
* [x] Validate file
* [x] Validate URL
* [x] Không execute file không tin cậy
* [ ] Secure IPC nếu có
* [x] Secure temporary files
* [x] Xóa sensitive data khỏi log

### 10. Apple Silicon / Intel

* [x] Apple Silicon `arm64`
* [x] Intel `x86_64`
* [ ] Universal Binary nếu hỗ trợ cả hai
* [x] Test trên Apple Silicon
* [ ] Test Intel nếu còn hỗ trợ
* [x] Không phụ thuộc binary chỉ chạy một architecture
* [x] Native performance
* [ ] Rosetta fallback nếu cần

### 11. Performance

* [x] Startup nhanh
* [x] Không block main thread
* [x] Background task
* [x] Async I/O
* [x] Memory usage hợp lý
* [x] CPU usage hợp lý
* [x] GPU usage hợp lý
* [x] Không memory leak
* [x] Không retain cycle
* [x] Không runaway process
* [x] Không unnecessary polling
* [x] Cache hợp lý
* [x] Large dataset không làm UI lag
* [x] App idle không ăn CPU

### 12. macOS integration

* [ ] Dock icon
* [ ] Dock menu nếu cần
* [x] Notifications
* [ ] Notification actions
* [ ] Share menu nếu cần
* [ ] Quick Look nếu cần
* [ ] Spotlight integration nếu cần
* [ ] Services nếu cần
* [ ] Handoff nếu cần
* [x] Universal Clipboard compatibility nếu cần
* [ ] Drag & Drop
* [ ] URL Scheme
* [ ] File associations
* [ ] Default application handling
* [x] Login Item nếu cần
* [x] Menu bar app nếu cần

### 13. Notifications

* [x] Request notification permission
* [x] Notification title
* [x] Notification body
* [ ] Notification action
* [ ] Deep link tới đúng màn hình
* [x] Không spam notification
* [x] Handle permission denied
* [x] Notification settings

### 14. Error handling

Mỗi lỗi cần:

* [x] Detect
* [x] Log
* [x] User-readable message
* [x] Recovery path
* [x] Retry nếu phù hợp
* [x] Không crash
* [x] Không expose technical secret

Các trường hợp:

* [x] Network error
* [x] Timeout
* [x] Authentication error
* [x] Permission denied
* [x] Invalid input
* [x] Invalid file
* [x] Disk full
* [x] Server error
* [x] Missing resource
* [x] Corrupted data
* [x] Unexpected exception

### 15. Data

* [x] Data model
* [x] Local database nếu cần
* [x] Persistence
* [x] Migration
* [ ] Backup strategy
* [x] Cache
* [x] Cache invalidation
* [x] Data export
* [x] Data deletion
* [ ] Reset app data
* [x] Corrupted database recovery

### 16. Network

Nếu app online:

* [ ] API client
* [ ] HTTPS
* [ ] Timeout
* [ ] Retry
* [ ] Offline handling
* [ ] Connection state
* [ ] API error handling
* [ ] Authentication
* [ ] Token refresh
* [ ] Logout
* [ ] Rate-limit handling
* [ ] Request cancellation
* [ ] Response validation

### 17. Login / Account

Nếu có account:

* [ ] Login
* [ ] Logout
* [ ] Register
* [ ] Forgot password
* [ ] Password reset
* [ ] Session persistence
* [ ] Token storage bằng Keychain
* [ ] Token expiration
* [ ] Refresh token
* [ ] Account deletion
* [ ] Profile
* [ ] Sync data

### 18. Accessibility

* [x] VoiceOver
* [x] Accessibility labels
* [x] Accessibility hints
* [x] Keyboard navigation
* [x] Focus order
* [x] Dynamic text nếu phù hợp
* [x] Reduced Motion
* [x] Reduced Transparency
* [x] High contrast
* [x] Không truyền thông tin chỉ bằng màu

### 19. Localization

Nếu app hỗ trợ nhiều ngôn ngữ:

* [x] Localizable strings
* [x] Vietnamese
* [x] English
* [x] Date format
* [x] Time format
* [x] Number format
* [ ] Currency
* [x] Text expansion
* [ ] RTL nếu cần
* [x] Không hard-code text trong UI

### 20. Logging

* [x] Structured logging
* [x] Log levels
* [x] Debug log
* [x] Production log
* [x] Không log password
* [x] Không log token
* [x] Không log API key
* [x] Không log sensitive user data
* [ ] Crash reporting nếu cần
* [ ] Log rotation nếu lưu local

### 21. Update

* [x] Version number
* [ ] Update checker
* [ ] Automatic update nếu cần
* [ ] Manual update
* [ ] Update notification
* [ ] Download update
* [ ] Verify update
* [ ] Rollback strategy nếu cần
* [ ] Migration giữa version

Nếu dùng Sparkle:

* [ ] Appcast
* [ ] Signed update
* [ ] Update feed
* [ ] EdDSA signing
* [ ] Release workflow

### 22. Distribution

Có 2 hướng chính:

App Store:

* [ ] Apple Developer account
* [ ] App ID
* [ ] Certificates
* [ ] Provisioning
* [ ] Sandbox
* [ ] App Store Connect
* [ ] App metadata
* [ ] Screenshots
* [ ] Privacy details
* [ ] Review guidelines
* [ ] Archive
* [ ] Upload
* [ ] TestFlight
* [ ] App Review

Phân phối ngoài App Store:

* [ ] Developer ID Application
* [x] Hardened Runtime
* [x] Code signing
* [ ] Notarization
* [ ] Stapling
* [ ] DMG / PKG
* [ ] Installer
* [ ] Update mechanism

### 23. DMG

Nếu phát hành `.dmg`:

* [ ] App `.app`
* [ ] Applications shortcut
* [ ] App icon
* [ ] Background
* [ ] DMG layout
* [ ] Volume name
* [ ] Code signing
* [ ] Notarization
* [ ] Staple notarization ticket
* [ ] Test clean Mac
* [ ] Test download từ Internet

### 24. Testing

Functional:

* [x] App launch
* [x] App quit
* [x] Every main feature
* [ ] Invalid input
* [x] Permission denied
* [ ] Offline
* [ ] Network failure
* [ ] Empty data
* [ ] Large data
* [ ] Corrupted data

UI:

* [x] Light Mode
* [x] Dark Mode
* [x] Retina
* [x] 4K
* [x] Different window sizes
* [x] Fullscreen
* [x] Multiple monitors
* [x] Accessibility

System:

* [x] Fresh macOS
* [x] Existing installation
* [x] Upgrade
* [x] Uninstall
* [x] Reinstall
* [x] Apple Silicon
* [ ] Intel nếu hỗ trợ

### 25. Crash / Recovery

* [ ] Crash reporter
* [ ] Crash logs
* [x] Auto-save
* [ ] State restoration
* [ ] Recovery after force quit
* [ ] Recovery after power loss
* [ ] Corrupted state handling
* [ ] Safe startup mode nếu app phức tạp

### 26. Uninstall

macOS app đơn giản:

* [x] `.app` có thể kéo vào Trash
* [x] Không để lại file rác quá mức

Nếu app có helper/service:

* [ ] Remove LaunchAgent
* [ ] Remove LaunchDaemon
* [ ] Remove Login Item
* [ ] Remove helper
* [ ] Remove cache
* [ ] Remove preferences
* [ ] Remove database nếu user chọn
* [ ] Remove Keychain data nếu cần

### 27. CI/CD

* [x] Git repository
* [x] Branch strategy
* [x] Automated build
* [x] Automated tests
* [x] Code signing
* [ ] Notarization
* [x] Versioning
* [ ] Release notes
* [x] Build artifacts
* [ ] Release pipeline
* [ ] Secrets management
* [x] Separate development / production config

### 28. Documentation

* [x] README
* [x] Installation
* [x] Requirements
* [x] Supported macOS versions
* [x] Supported CPU architectures
* [x] Permissions
* [x] Configuration
* [x] Troubleshooting
* [x] FAQ
* [ ] Privacy policy nếu cần
* [x] License
* [ ] Changelog

### 29. Privacy

* [x] Data collection inventory
* [ ] Privacy policy
* [ ] Analytics disclosure
* [ ] Crash reporting disclosure
* [ ] User consent nếu cần
* [x] Data retention
* [x] Data deletion
* [x] Third-party SDK audit
* [ ] App Store privacy labels nếu phát hành App Store

### 30. Release checklist

Trước release:

* [x] Version tăng đúng
* [x] Build Release
* [x] Tests pass
* [x] No debug code
* [x] No debug logs nhạy cảm
* [x] No API secrets
* [x] Code signed
* [ ] Notarized
* [x] Clean Mac install test
* [x] Upgrade test
* [x] Uninstall test
* [x] Apple Silicon test
* [ ] Intel test nếu hỗ trợ
* [x] Dark Mode test
* [x] Accessibility test
* [x] Network failure test
* [x] Permission denial test
* [x] Crash test
* [x] Documentation cập nhật
* [x] Release notes
* [x] Backup release artifact

### Nếu mục tiêu là app macOS "chuẩn để phát hành"

Mức tối thiểu nên đạt:

`Native UI → Window/Menu → Settings → Persistence → Error handling → Permissions → Keychain → Sandbox → Code Signing → Hardened Runtime → Notarization → Auto Update → Testing → Documentation`

Nếu app của bạn là app desktop cụ thể, có thể tách checklist thành 3 tầng: `MVP → Production → App Store/Commercial`, sẽ dễ triển khai hơn.
