import SwiftUI

/// 새 프로젝트 창 — 자체 AppState를 소유하며 autosave를 로드하지 않는다.
struct NewProjectWindowView: View {
    @State private var appState = AppState(isNew: true)

    var body: some View {
        MainWindowView()
            .environment(appState)
            .frame(minWidth: 600, minHeight: 400)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.willTerminateNotification)
            ) { _ in
                // 새 창도 종료 시 자체 상태를 보존하지 않는다 (autosave는 메인 창 담당)
            }
    }
}
