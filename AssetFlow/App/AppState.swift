import SwiftUI

nonisolated enum AppFeature: String, CaseIterable, Identifiable {
    case iconDesign    = "Icon Design"
    case iconExport    = "Icon Export"
    case screenshots   = "Screenshots"
    case stringManager = "Strings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .iconDesign:    return "paintbrush.pointed"
        case .iconExport:    return "square.and.arrow.up.on.square"
        case .screenshots:   return "iphone.gen3"
        case .stringManager: return "character.bubble"
        }
    }
}

@Observable
@MainActor
final class AppState {
    var selectedFeature: AppFeature = .iconDesign
    var iconDesignViewModel = IconDesignViewModel()
    
    func iconDesignZoomIn() {
        iconDesignViewModel.zoomIn()
    }
    
    func iconDesignZoomOut() {
        iconDesignViewModel.zoomOut()
    }
}
