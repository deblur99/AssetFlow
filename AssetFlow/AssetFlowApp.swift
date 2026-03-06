import SwiftUI

@main
struct AssetFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
                .frame(minWidth: 600, minHeight: 400)  // 최소 창 크기
        }
        .defaultSize(width: 1080, height: 800) // 초기 창 크기
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
