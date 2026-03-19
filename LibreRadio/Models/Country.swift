import Foundation

struct Country: Codable, Identifiable, Sendable {
    var id: String { iso_3166_1 }

    let name: String
    let iso_3166_1: String
    let stationcount: Int

    var displayName: String {
        guard !iso_3166_1.isEmpty,
              let localized = Locale(identifier: "en").localizedString(forRegionCode: iso_3166_1)
        else { return name }
        return localized
    }
}
