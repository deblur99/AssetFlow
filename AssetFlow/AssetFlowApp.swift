import SwiftUI

@main
struct AssetFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    // 앱 종료 직전 즉시 저장 (debounce 대기 없이)
                    ProjectFileService.saveAutosave(
                        appState.iconDesignViewModel.project)
                }
        }
        .defaultSize(width: 1080, height: 800)
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
