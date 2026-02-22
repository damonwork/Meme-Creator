import Foundation

func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[MemeCreator][\(timestamp)] \(message())")
#endif
}
