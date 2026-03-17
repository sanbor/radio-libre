import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct RadioActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        let stationName: String
        let codec: String?
        let bitrateLabel: String
        let flagEmoji: String?
        let countryName: String?
        let isPlaying: Bool
        let isLoading: Bool
        let isBuffering: Bool
        let faviconData: Data?
    }
}
