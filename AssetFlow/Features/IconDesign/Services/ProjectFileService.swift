import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType

extension UTType {
    /// AssetFlow 프로젝트 파일 (.asflow)
    static let assetflowProject = UTType(
        exportedAs: "com.deblurlab.assetflow-project",
        conformingTo: .data
    )
}

// MARK: - ProjectFileService

@MainActor
enum ProjectFileService {
    // MARK: - Autosave (무음 저장/복원)

    /// ~/Library/Application Support/AssetFlow/autosave.asflow
    static var autosaveURL: URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = base.appendingPathComponent("AssetFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("autosave.asflow")
    }

    /// 알림 없이 자동저장 파일에 쓴다.
    static func saveAutosave(_ project: IconProject) {
        guard let url = autosaveURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(project).write(to: url, options: .atomic)
    }

    /// 자동저장 파일이 있으면 읽어 반환한다. 없거나 파싱 실패 시 nil.
    static func loadAutosave() -> IconProject? {
        guard let url = autosaveURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(IconProject.self, from: data)
    }

    // MARK: - Save

    static func saveProject(_ project: IconProject) async {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.assetflowProject]
        panel.nameFieldStringValue = project.name
        panel.message = "AssetFlow 프로젝트 파일로 저장합니다."

        guard await panel.begin() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(project).write(to: url, options: .atomic)
            showSaveResult(url: url, error: nil)
        } catch {
            showSaveResult(url: url, error: error)
        }
    }

    // MARK: - Open / Import

    static func openProject() async -> IconProject? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.assetflowProject]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "열 AssetFlow 프로젝트 파일을 선택하세요."

        guard await panel.begin() == .OK,
              let url = panel.url
        else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(IconProject.self, from: Data(contentsOf: url))
        } catch {
            showOpenError(error)
            return nil
        }
    }

    /// PNG 파일을 선택하여 새 프로젝트로 변환한다.
    /// - 캔버스 크기: 이미지 실제 크기 (단, 최소 1×1, 최대 4096×4096으로 클램프)
    /// - 레이어 구성: 흰색 배경 + PNG 이미지 레이어 (캔버스 전체 크기)
    static func openPNGAsProject() async -> IconProject? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "프로젝트로 변환할 PNG 파일을 선택하세요."

        guard await panel.begin() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url)
        else { return nil }

        let projectName = url.deletingPathExtension().lastPathComponent
        let naturalSize = image.size
        let clamp: (CGFloat) -> CGFloat = { min(max($0, 1), 4096) }
        let canvasSize = CGSize(width: clamp(naturalSize.width),
                                height: clamp(naturalSize.height))

        var project = IconProject(name: projectName, canvasSize: canvasSize)
        let imageElement = ImageElement(
            id: UUID(),
            name: projectName,
            frame: CGRect(origin: .zero, size: canvasSize),
            image: image
        )
        project.elements.append(.image(imageElement))
        return project
    }

    // MARK: - Alerts

    private static func showSaveResult(url: URL, error: Error?) {
        let alert = NSAlert()
        if let error {
            alert.alertStyle = .critical
            alert.messageText = "프로젝트 저장 실패"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "확인")
            alert.runModal()
        } else {
            alert.alertStyle = .informational
            alert.messageText = "프로젝트 저장 완료"
            alert.informativeText = url.path
            alert.addButton(withTitle: "Finder에서 열기")
            alert.addButton(withTitle: "확인")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private static func showOpenError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "프로젝트 열기 실패"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}
