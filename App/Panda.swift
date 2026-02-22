/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

struct Panda: Codable, Hashable, Identifiable {
    var id: String { imageUrl?.absoluteString ?? description }
    var description: String
    var imageUrl: URL?
    
    static let defaultPanda = Panda(
        description: "Cute Panda",
        imageUrl: URL(string: "http://playgrounds-cdn.apple.com/assets/pandas/pandaBuggingOut.jpg")
    )
}

struct PandaCollection: Codable {
    var sample: [Panda]
}
