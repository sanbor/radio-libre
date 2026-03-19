import Foundation

enum BrowseSortOrder: String, CaseIterable {
    case alphabetical
    case byStationCount

    var label: String {
        switch self {
        case .alphabetical: "Name"
        case .byStationCount: "Stations"
        }
    }
}
