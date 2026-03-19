import AppKit

// MARK: - AppDelegate

/// Finder 또는 외부에서 .asflow 파일을 열 때 SwiftUI 기본 동작(새 WindowGroup 창 생성)을
/// 대신해서 처리한다.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Finder, Dock, NSWorkspace.open 등으로 .asflow 파일이 열릴 때 호출된다.
    func application(_ application: NSApplication, open urls: [URL]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let project = try? decoder.decode(IconProject.self, from: data)
            else { continue }

            Task { @MainActor in
                // 동일 프로젝트 ID의 창이 이미 열려 있으면 포커스만 이동한다.
                if !NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                    NewProjectWindowManager.shared.open(with: project)
                }
            }
        }
    }
}
