import SwiftUI

nonisolated enum DrawingTool: String, CaseIterable, Identifiable {
    case select    = "Select"
    case pen       = "Pen"
    case rectangle = "Rectangle"
    case ellipse   = "Ellipse"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .select:    return "arrow.up.left.and.arrow.down.right"
        case .pen:       return "pencil"
        case .rectangle: return "rectangle"
        case .ellipse:   return "circle"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .select:    return "v"
        case .pen:       return "p"
        case .rectangle: return "r"
        case .ellipse:   return "e"
        }
    }
}
