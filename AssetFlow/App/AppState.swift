import SwiftUI

nonisolated enum AppFeature: String, CaseIterable, Identifiable {
    case iconDesign    = "Icon Design"
    case stringManager = "Strings"
    case showcase      = "Showcase"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .iconDesign:    return "paintbrush.pointed"
        case .stringManager: return "character.bubble"
        case .showcase:      return "iphone.gen3"
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
