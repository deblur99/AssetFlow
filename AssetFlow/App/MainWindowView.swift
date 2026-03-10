import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) var appState: AppState

    var body: some View {
        @Bindable var appState = appState
        
        NavigationSplitView {
            List(
                AppFeature.allCases,
                selection: $appState.selectedFeature
            ) { feature in
                Label(feature.rawValue, systemImage: feature.systemImage)
                    .tag(feature)
            }
            .navigationTitle("AssetFlow")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch appState.selectedFeature {
            case .iconDesign: IconDesignView()
            case .showcase: ShowcaseView()
            case .stringManager: StringManagerView()
            }
        }
    }
}
