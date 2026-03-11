import SwiftUI

@main
struct AssetFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)  // 최소 창 크기
        }
        .defaultSize(width: 1080, height: 800) // 초기 창 크기
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(before: .toolbar) {
                Button("Zoom In", systemImage: "plus.magnifyingglass") {
                    appState.iconDesignZoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])
                
                Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                    appState.iconDesignZoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
