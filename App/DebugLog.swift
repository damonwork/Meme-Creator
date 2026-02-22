import Foundation
import SwiftUI
import UIKit

func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    let timestamp = DebugLogFormatter.shared.string(from: Date())
    print("[MemeCreator][\(timestamp)] \(message())")
#endif
}

func debugLogThrottled(
    _ key: String,
    interval: TimeInterval = 0.35,
    _ message: @autoclosure () -> String
) {
#if DEBUG
    guard DebugLogThrottleStore.shared.shouldLog(key: key, interval: interval) else { return }
    debugLog(message())
#endif
}

func debugColorRGBA(_ color: Color) -> String {
    let uiColor = UIColor(color)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
        return "unresolved"
    }

    return String(
        format: "rgba(%.2f,%.2f,%.2f,%.2f)",
        red,
        green,
        blue,
        alpha
    )
}

#if DEBUG
private enum DebugLogFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private final class DebugLogThrottleStore {
    static let shared = DebugLogThrottleStore()

    private var lastLogByKey: [String: Date] = [:]
    private let lock = NSLock()

    private init() {}

    func shouldLog(key: String, interval: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if let last = lastLogByKey[key], now.timeIntervalSince(last) < interval {
            return false
        }
        lastLogByKey[key] = now
        return true
    }
}
#endif
