import AppKit
import SwiftUI

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    // welcome 창 — strong reference로 유지, 닫히면 앱 종료
    private var welcomeWindow: NSWindow?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI WindowGroup이 자동으로 여는 빈 placeholder 창을 숨긴다.
        // close() 대신 orderOut()을 사용해 SwiftUI가 창을 재생성하지 않도록 하고,
        // isExcludedFromWindowsMenu로 독 Application Windows 목록에 나타나지 않게 한다.
        DispatchQueue.main.async { [weak self] in
            for window in NSApp.windows where !(window is NSPanel) {
                window.isExcludedFromWindowsMenu = true
                window.collectionBehavior = [.ignoresCycle]
                window.orderOut(nil)
            }
            self?.showWelcomeWindow()
        }
    }

    // MARK: - Welcome window

    func showWelcomeWindow() {
        if let existing = welcomeWindow {
            // 기존 창이 있으면 최신 데이터를 반영한 새 뷰로 교체 후 앞으로 가져온다.
            (existing.contentViewController as? NSHostingController<WelcomeView>)?.rootView = WelcomeView()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 프로젝트를 열 때 welcome 창을 숨긴다.
    /// close() 대신 orderOut()을 사용해 welcomeWindow 참조를 유지하면서 화면에서만 제거한다.
    /// close()를 쓰면 windowWillClose가 발화해 welcomeWindow가 nil이 되고,
    /// 독 메뉴에서 창 항목을 클릭해도 창이 복원되지 않는 문제가 생긴다.
    func closeWelcomeWindow() {
        welcomeWindow?.orderOut(nil)
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
    /// hasVisibleWindows만으로는 SwiftUI WindowGroup 잔여 창 등의 영향을 받으므로,
    /// 프로젝트 창이 없을 때는 항상 환영 화면을 표시한다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows || NewProjectWindowManager.shared.allViewModels.isEmpty {
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
                NewProjectWindowManager.shared.open(with: project)
                self.closeWelcomeIfProjectOpen()
            } else {
                guard let data = try? Data(contentsOf: url),
                      let project = try? decoder.decode(IconProject.self, from: data)
                else { continue }
                
                if !NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                    NewProjectWindowManager.shared.open(with: project, fromFile: true)
                    RecentProjectsService.shared.add(name: project.name, url: url)
                }
                self.closeWelcomeIfProjectOpen()
            }
        }
    }

    // MARK: - Helpers

    /// 프로젝트 창이 열렸으면 welcome 창을 숨긴다.
    /// close() 대신 orderOut()을 사용해 welcomeWindow 참조를 유지한다.
    /// close()를 쓰면 windowWillClose가 발화해 welcomeWindow = nil 되고,
    /// 이후 showWelcomeWindow()가 새 창을 만들어 독 메뉴에 고스트 창이 누적된다.
    func closeWelcomeIfProjectOpen() {
        if !NewProjectWindowManager.shared.allViewModels.isEmpty {
            welcomeWindow?.orderOut(nil)
        }
    }
}

// MARK: - NSWindowDelegate (welcome window 닫기)

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === welcomeWindow else { return }
        // 사용자가 X 버튼으로 직접 닫은 경우에만 참조를 해제한다.
        // orderOut()으로 숨기는 경우에는 이 메서드가 호출되지 않는다.
        welcomeWindow = nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === welcomeWindow else { return }
        // 독 메뉴 클릭 등으로 창이 활성화될 때 최신 데이터로 뷰를 갱신한다.
        (welcomeWindow?.contentViewController as? NSHostingController<WelcomeView>)?.rootView = WelcomeView()
    }
}
