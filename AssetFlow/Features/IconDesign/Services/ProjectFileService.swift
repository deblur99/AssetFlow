import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - UTType

extension UTType {
    /// AssetFlow 프로젝트 파일 (.asflow)
    static let assetflowProject = UTType(exportedAs: "com.assetflow.project", conformingTo: .data)
}

// MARK: - ProjectFileService

@MainActor
enum ProjectFileService {

    // MARK: - Save

    static func saveProject(_ project: IconProject) {
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.allowedContentTypes  = [.assetflowProject]
            panel.nameFieldStringValue = project.name
            panel.message              = "AssetFlow 프로젝트 파일로 저장합니다."

            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting    = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(project).write(to: url, options: .atomic)
                showSaveResult(url: url, error: nil)
            } catch {
                showSaveResult(url: url, error: error)
            }
        }
    }

    // MARK: - Open / Import

    static func openProject(completion: @escaping @MainActor (IconProject) -> Void) {
        Task { @MainActor in
            let panel = NSOpenPanel()
            panel.allowedContentTypes    = [.assetflowProject]
            panel.canChooseFiles         = true
            panel.canChooseDirectories   = false
            panel.allowsMultipleSelection = false
            panel.message                = "열 AssetFlow 프로젝트 파일을 선택하세요."

            guard await panel.begin() == .OK, let url = panel.url else { return }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let project = try decoder.decode(IconProject.self, from: Data(contentsOf: url))
                completion(project)
            } catch {
                showOpenError(error)
            }
        }
    }

    // MARK: - Alerts

    private static func showSaveResult(url: URL, error: Error?) {
        let alert = NSAlert()
        if let error {
            alert.alertStyle      = .critical
            alert.messageText     = "프로젝트 저장 실패"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "확인")
            alert.runModal()
        } else {
            alert.alertStyle      = .informational
            alert.messageText     = "프로젝트 저장 완료"
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
        alert.alertStyle      = .critical
        alert.messageText     = "프로젝트 열기 실패"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}
