/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

struct Panda: Codable, Hashable, Identifiable {
    let id = UUID()
    var description: String
    var imageUrl: URL?

    enum CodingKeys: String, CodingKey {
        case description
        case imageUrl
    }
    
    static let defaultPanda = Panda(
        description: "Cute Panda",
        imageUrl: URL(string: "http://playgrounds-cdn.apple.com/assets/pandas/pandaBuggingOut.jpg")
    )
}

struct PandaCollection: Codable {
    var sample: [Panda]
}
