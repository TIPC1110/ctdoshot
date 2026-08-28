import Foundation
import AppKit
// ponytail: scaffold — CanvasState from DrawingCanvasView (Task 9). Real undo/redo + tool state deferred, stub keeps build green.
public struct CanvasState {
    public var elements: [String] = []
    private var redoStack: [String] = []
    public var thickness: CGFloat = 2 // Task 11: persisted thickness stub
    public var zoom: CGFloat = 1.0   // 1.0=100%, 2.0=200%
    public mutating func add(_ e: String) { elements.append(e); redoStack.removeAll() }
    public mutating func undo() { if let last = elements.popLast() { redoStack.append(last) } }
    public mutating func redo() { if let last = redoStack.popLast() { elements.append(last) } }
}
