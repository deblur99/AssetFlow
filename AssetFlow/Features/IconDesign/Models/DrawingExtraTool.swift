//
//  DrawingExtraTool.swift
//  AssetFlow
//
//  Created by 한현민 on 3/11/26.
//

import SwiftUI

nonisolated enum DrawingExtraTool: String, ToolItem {
    case imagePicker = "Image Picker"
    case showGrid = "Show Grid"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .imagePicker: return "photo"
        case .showGrid: return "grid"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .imagePicker: return "i"
        case .showGrid: return "g"
        }
    }

    var helpText: String {
        switch self {
        case .imagePicker: return "Show Image — ⌘I"
        case .showGrid: return "Show Grid — ⌘G"
        }
    }
}
