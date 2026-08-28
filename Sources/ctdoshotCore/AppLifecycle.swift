import AppKit
// ponytail: scaffold — AppLifecycle extracted from AppDelegate (Task 8). Thin wiring, full delegate split deferred.
public final class AppLifecycle: NSObject {
    public func setupNotifications() {}
    public func setupHotkey(with delegate: AppDelegate) {}
}
