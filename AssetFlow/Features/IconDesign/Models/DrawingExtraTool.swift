//
//  DrawingExtraTool.swift
//  AssetFlow
//
//  Created by 한현민 on 3/11/26.
//

import SwiftUI

nonisolated enum DrawingExtraTool: String, ToolItem {
    case imagePicker = "Image Picker"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .imagePicker: return "photo"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .imagePicker: return "i"
        }
    }

    var helpText: String {
        switch self {
        case .imagePicker: return "Import Image — ⌘I"
        }
    }
}
