import SwiftUI

nonisolated enum DrawingTool: String, CaseIterable, Identifiable {
    case move      = "Move"
    case select    = "Select"
    case pen       = "Pen"
    case rectangle = "Rectangle"
    case ellipse   = "Ellipse"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .move:      return "hand.point.up.left"
        case .select:    return "rectangle.dashed"
        case .pen:       return "pencil"
        case .rectangle: return "rectangle"
        case .ellipse:   return "circle"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .move:      return "1"
        case .select:    return "2"
        case .pen:       return "3"
        case .rectangle: return "4"
        case .ellipse:   return "5"
        }
    }
}
