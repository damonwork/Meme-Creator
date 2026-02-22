/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI
import SwiftData

@Model
final class SavedMeme {
    @Attribute(.externalStorage) var imageData: Data
    var createdAt: Date
    var title: String
    
    init(imageData: Data, title: String = "", createdAt: Date = .now) {
        self.imageData = imageData
        self.title = title
        self.createdAt = createdAt
    }
    
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}
