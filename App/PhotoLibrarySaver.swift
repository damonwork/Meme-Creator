import UIKit

final class PhotoLibrarySaver: NSObject {
    static let shared = PhotoLibrarySaver()

    private var completions: [String: (Error?) -> Void] = [:]

    func save(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        let token = UUID().uuidString
        completions[token] = completion
        let context = Unmanaged.passRetained(token as NSString).toOpaque()
        UIImageWriteToSavedPhotosAlbum(
            image,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            context
        )
    }

    @objc
    private func image(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let contextInfo else { return }
        let token = Unmanaged<NSString>.fromOpaque(contextInfo).takeRetainedValue() as String
        let completion = completions.removeValue(forKey: token)
        completion?(error)
    }
}
