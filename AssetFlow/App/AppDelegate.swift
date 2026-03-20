import AppKit

// MARK: - AppDelegate

/// Finder 또는 외부에서 .asflow 파일을 열 때 SwiftUI 기본 동작(새 WindowGroup 창 생성)을
/// 대신해서 처리한다.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Finder, Dock, NSWorkspace.open 등으로 파일이 열릴 때 호출된다.
    /// - .asflow: 프로젝트 파일로 디코딩하여 창을 연다.
    /// - .png: PNG를 이미지 레이어로 갖는 새 프로젝트로 변환하여 창을 연다.
    func application(_ application: NSApplication, open urls: [URL]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in urls {
            if url.pathExtension.lowercased() == "png" {
                // PNG → 새 프로젝트로 변환
                guard let image = NSImage(contentsOf: url) else { continue }
                let projectName = url.deletingPathExtension().lastPathComponent
                let clamp: (CGFloat) -> CGFloat = { min(max($0, 1), 4096) }
                let canvasSize = CGSize(width:  clamp(image.size.width),
                                       height: clamp(image.size.height))
                var project = IconProject(name: projectName, canvasSize: canvasSize)
                let imageElement = ImageElement(
                    id: UUID(),
                    name: projectName,
                    frame: CGRect(origin: .zero, size: canvasSize),
                    image: image
                )
                project.elements.append(.image(imageElement))
                Task { @MainActor in
                    NewProjectWindowManager.shared.open(with: project)
                }
            } else {
                // .asflow 프로젝트 파일
                guard let data = try? Data(contentsOf: url),
                      let project = try? decoder.decode(IconProject.self, from: data)
                else { continue }
                Task { @MainActor in
                    if !NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                        NewProjectWindowManager.shared.open(with: project)
                    }
                }
            }
        }
    }
}
