import AppKit
// ponytail: scaffold — StatusBarController extracted from AppDelegate (Task 8). Full wiring deferred, minimal keeps build green.
public final class StatusBarController: NSObject {
    public var statusItem: NSStatusItem?
    public func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ctdoshot")
    }
    public func rebuildMenu(with delegate: AppDelegate) { delegate.rebuildMenu() }
}
