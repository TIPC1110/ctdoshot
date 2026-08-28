import Foundation
import AppKit
// ponytail: scaffold — CanvasState from DrawingCanvasView (Task 9). Real undo/redo + tool state deferred, stub keeps build green.
public struct CanvasState {
    public var elements: [String] = []
    public var thickness: CGFloat = 2 // Task 11: persisted thickness stub
    public var zoom: CGFloat = 1.0   // 1.0=100%, 2.0=200%
    public mutating func add(_ e: String) { elements.append(e) }
    public mutating func undo() { _ = elements.popLast() }
    public mutating func redo() {}
}
