import Foundation

func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    let timestamp = DebugLogFormatter.shared.string(from: Date())
    print("[MemeCreator][\(timestamp)] \(message())")
#endif
}

#if DEBUG
private enum DebugLogFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
#endif
