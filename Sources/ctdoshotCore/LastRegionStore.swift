import Foundation
import CoreGraphics

public enum LastRegionStore {
    private static let key = "capture.lastRegion"

    public struct Payload: Codable {
        public var x, y, w, h: Double
        public var displayID: UInt32

        public init(x: Double, y: Double, w: Double, h: Double, displayID: UInt32) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
            self.displayID = displayID
        }
    }

    public static func save(_ rect: CGRect, displayID: UInt32) {
        let p = Payload(
            x: rect.minX,
            y: rect.minY,
            w: rect.width,
            h: rect.height,
            displayID: displayID
        )
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public static func load() -> (CGRect, UInt32)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return (CGRect(x: p.x, y: p.y, width: p.w, height: p.h), p.displayID)
    }
}
