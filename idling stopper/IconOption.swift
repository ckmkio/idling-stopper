import Foundation

enum IconOption: String, CaseIterable, Identifiable {
    case cursor
    case cloud
    case person
    case hexagon

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .cursor:  "cursorarrow.motionlines"
        case .cloud:   "cloud.fill"
        case .person:  "person.fill"
        case .hexagon: "hexagon.fill"
        }
    }

    var label: String {
        switch self {
        case .cursor:  "Cursor"
        case .cloud:   "Cloud"
        case .person:  "Person"
        case .hexagon: "Hexagon"
        }
    }

    static let `default`: IconOption = .cursor
}
