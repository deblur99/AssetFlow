import SwiftUI

nonisolated enum DrawingTool: String, ToolItem {
    case move = "Move"
    case select = "Select"
    case pen = "Pen"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case text = "Text"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .move: return "hand.raised"
        case .select: return "arrow.up.left"
        case .pen: return "pencil"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "text.cursor"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .move: return "1"
        case .select: return "2"
        case .pen: return "3"
        case .rectangle: return "4"
        case .ellipse: return "5"
        case .text: return "T"
        }
    }

    var helpText: String {
        switch self {
        case .move: return "Move (Pan Canvas) — ⌘1"
        case .select: return "Select — ⌘2"
        case .pen: return "Pen — ⌘3"
        case .rectangle: return "Rectangle — ⌘4"
        case .ellipse: return "Ellipse — ⌘5"
        case .text: return "Text — ⌘T"
        }
    }
}
