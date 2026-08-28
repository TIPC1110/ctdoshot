# Support

## Screen Recording Permission
1. System Settings → Privacy & Security → Screen Recording → enable ctdoshot
2. Quit fully (⌘Q) and reopen the same .app (build/ctdoshot.app or /Applications/ctdoshot.app)
3. If stuck: `tccutil reset ScreenCapture com.ctdoshot.app`, rebuild, grant once, quit, reopen
4. Check signing: `codesign -dv --verbose=2 /Applications/ctdoshot.app` — should show `Authority=ctdoshot Developer` (not ad-hoc)

## TroubleshootingView
Preferences → Troubleshooting shows signing info and copyable reset command.

## Issues
https://github.com/TIPC1110/ctdoshot/issues
