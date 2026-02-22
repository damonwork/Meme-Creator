/*
See the License.txt file for this sample's licensing information.
*/

import SwiftUI

@MainActor
class PandaCollectionFetcher: ObservableObject {
    @Published var imageData = PandaCollection(sample: [Panda.defaultPanda])
    @Published var currentPanda = Panda.defaultPanda
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    let urlString = "http://playgrounds-cdn.apple.com/assets/pandaData.json"
    
    enum FetchError: Error, LocalizedError {
        case badRequest
        case badJSON
        case noConnection
        
        var errorDescription: String? {
            switch self {
            case .badRequest:
                return "Failed to load panda data. Please try again."
            case .badJSON:
                return "Failed to parse panda data. The data may be corrupted."
            case .noConnection:
                return "No internet connection. Please check your network."
            }
        }
    }
    
    func fetchData() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL configuration."
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw FetchError.badRequest
            }
            
            // Decode off the implicit main actor context by using a nonisolated helper
            let decoded = try decodePandaCollection(from: data)
            
            // Fix image URLs: API returns https:// but server only responds on http://
            let fixedSamples = decoded.sample.map { panda in
                var fixed = panda
                if let imageUrlString = panda.imageUrl?.absoluteString,
                   imageUrlString.hasPrefix("https://playgrounds-cdn.apple.com") {
                    fixed.imageUrl = URL(string: imageUrlString.replacingOccurrences(of: "https://", with: "http://"))
                }
                return fixed
            }
            
            imageData = PandaCollection(sample: fixedSamples)
            if let first = fixedSamples.first {
                currentPanda = first
            }
        } catch is URLError {
            errorMessage = FetchError.noConnection.errorDescription
        } catch let error as FetchError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = FetchError.badJSON.errorDescription
        }
        
        isLoading = false
    }
    
    private nonisolated func decodePandaCollection(from data: Data) throws -> PandaCollection {
        try JSONDecoder().decode(PandaCollection.self, from: data)
    }
    
    func shufflePanda() {
        if let randomPanda = imageData.sample.randomElement() {
            currentPanda = randomPanda
        }
    }
}
