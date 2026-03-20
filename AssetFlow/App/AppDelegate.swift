import AppKit
import SwiftUI

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // welcome 창 — strong reference로 유지, 닫히면 앱 종료
    private var welcomeWindow: NSWindow?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI WindowGroup이 자동으로 여는 빈 placeholder 창을 닫은 뒤 환영 창을 연다.
        // async 디스패치로 SwiftUI가 WindowGroup 창을 생성한 이후에 실행을 보장한다.
        DispatchQueue.main.async { [weak self] in
            for window in NSApp.windows where !(window is NSPanel) {
                window.close()
            }
            self?.showWelcomeWindow()
        }
    }

    // MARK: - Welcome window

    func showWelcomeWindow() {
        // welcomeWindow가 이미 존재하면 isVisible 상태와 무관하게 재사용한다.
        // isVisible 체크는 창이 생성됐지만 아직 표시되기 전(async 타이밍)에 중복 생성되는 문제를 유발한다.
        if let existing = welcomeWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let vc = NSHostingController(rootView: WelcomeView())
        let window = NSWindow(contentViewController: vc)
        window.title = "AssetFlow"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Lifecycle

    /// 마지막 창이 닫혀도 앱을 종료하지 않는다. 창 관리는 직접 처리한다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// 앱이 정상 종료되기 직전 autosave 파일을 삭제한다 (크래시 복구 파일은 크래시 시에만 유지).
    func applicationWillTerminate(_ notification: Notification) {
        AutoSaveService.clear()
        if let url = ProjectFileService.autosaveURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Cmd+Q 시 저장 경고창을 표시한다.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let vms = NewProjectWindowManager.shared.allViewModels
        guard !vms.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "AssetFlow를 종료하시겠습니까?"
        alert.informativeText = "저장되지 않은 변경 사항은 사라집니다."
        alert.addButton(withTitle: "저장하고 종료")
        alert.addButton(withTitle: "취소")
        alert.addButton(withTitle: "저장하지 않고 종료")
        alert.buttons[2].hasDestructiveAction = true

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task { @MainActor in
                for vm in vms {
                    let saved = await ProjectFileService.saveProject(vm.project)
                    if !saved {
                        NSApp.reply(toApplicationShouldTerminate: false)
                        return
                    }
                }
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        case .alertSecondButtonReturn:
            return .terminateCancel
        default:
            return .terminateNow
        }
    }

    /// Dock 아이콘 클릭 등으로 재활성화 시 환영 화면을 앞으로 가져온다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showWelcomeWindow()
        }
        return true
    }

    // MARK: - File open

    func application(_ application: NSApplication, open urls: [URL]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for url in urls {
            if url.pathExtension.lowercased() == "png" {
                guard let image = NSImage(contentsOf: url) else { continue }
                let projectName = url.deletingPathExtension().lastPathComponent
                let clamp: (CGFloat) -> CGFloat = { min(max($0, 1), 4096) }
                let canvasSize = CGSize(width: clamp(image.size.width),
                                       height: clamp(image.size.height))
                var project = IconProject(name: projectName, canvasSize: canvasSize)
                project.elements.append(.image(ImageElement(
                    id: UUID(), name: projectName,
                    frame: CGRect(origin: .zero, size: canvasSize), image: image
                )))
                Task { @MainActor in
                    NewProjectWindowManager.shared.open(with: project)
                    self.closeWelcomeIfProjectOpen()
                }
            } else {
                guard let data = try? Data(contentsOf: url),
                      let project = try? decoder.decode(IconProject.self, from: data)
                else { continue }
                Task { @MainActor in
                    if !NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                        NewProjectWindowManager.shared.open(with: project, fromFile: true)
                        RecentProjectsService.shared.add(name: project.name, url: url)
                    }
                    self.closeWelcomeIfProjectOpen()
                }
            }
        }
    }

    // MARK: - Helpers

    /// 프로젝트 창이 열렸으면 welcome 창을 닫는다.
    func closeWelcomeIfProjectOpen() {
        if !NewProjectWindowManager.shared.allViewModels.isEmpty {
            welcomeWindow?.close()
        }
    }
}

// MARK: - NSWindowDelegate (welcome window 닫기)

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === welcomeWindow else { return }
        welcomeWindow = nil  // 다음 showWelcomeWindow() 호출 시 새로 생성하도록 초기화
        if NewProjectWindowManager.shared.allViewModels.isEmpty {
            NSApp.terminate(nil)
        }
    }
}
