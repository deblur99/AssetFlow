import AppKit
import SwiftUI

// MARK: - 모든 프로젝트 창을 추적하고 동일 프로젝트 중복 열기를 방지한다.

@MainActor
final class NewProjectWindowManager {
    static let shared = NewProjectWindowManager()

    private struct WindowEntry {
        let windowController: NSWindowController?  // AppKit 창은 strong reference, SwiftUI 관리 창은 nil
        weak var window: NSWindow?
        let appState: AppState
    }

    private var entries: [WindowEntry] = []

    private init() {}

    // MARK: - Registration

    /// 창과 그에 연결된 AppState를 레지스트리에 등록한다.
    /// 동일한 창이 이미 등록돼 있으면 무시한다.
    /// - Parameter windowController: AppKit으로 직접 생성한 창은 컨트롤러를 전달해 생명주기를 유지한다.
    func registerWindow(_ window: NSWindow, appState: AppState, windowController: NSWindowController? = nil) {
        purgeClosedEntries()
        guard !entries.contains(where: { $0.window === window }) else { return }

        entries.append(WindowEntry(windowController: windowController, window: window,
                                   appState: appState))

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.entries.removeAll { $0.window == nil || $0.window === window }
                // 모든 프로젝트 창이 닫히면 환영 화면을 표시한다
                if self?.entries.isEmpty == true {
                    (NSApp.delegate as? AppDelegate)?.showWelcomeWindow()
                }
            }
        }
    }

    // MARK: - New project window

    /// 새 창을 연다.
    /// - Parameters:
    ///   - project: nil이면 빈 새 프로젝트, non-nil이면 해당 프로젝트를 로드한다.
    ///   - fromFile: true이면 .asflow 파일에서 연 것으로 표시해 자동저장을 활성화한다.
    func open(with project: IconProject? = nil, fromFile: Bool = false) {
        let appState = AppState(isNew: true)
        if let project {
            appState.iconDesignViewModel.loadProject(project)
            if fromFile { appState.iconDesignViewModel.markSavedToFile() }
        }

        let content = MainWindowView()
            .environment(appState)
            .frame(minWidth: 600, minHeight: 400)

        let hostingController = NSHostingController(rootView: content)

        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 1080, height: 800))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable,
                            .fullSizeContentView]
        window.title = appState.iconDesignViewModel.project.name
        window.toolbarStyle = .unified
        window.center()
        window.isReleasedWhenClosed = false

        let wc = NSWindowController(window: window)
        wc.showWindow(nil)

        registerWindow(window, appState: appState, windowController: wc)
    }

    // MARK: - Deduplication

    /// 주어진 프로젝트 ID를 가진 창이 이미 열려 있으면 해당 창을 맨 앞으로 가져오고 true를 반환한다.
    @discardableResult
    func focusWindowIfOpen(projectID: UUID) -> Bool {
        purgeClosedEntries()
        guard let entry = entries.first(where: {
            $0.appState.iconDesignViewModel.canvasState.id == projectID
        }), let window = entry.window else {
            return false
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    // MARK: - ViewModels

    /// 현재 열려 있는 모든 창의 ViewModel 목록을 반환한다.
    var allViewModels: [IconDesignViewModel] {
        purgeClosedEntries()
        return entries.compactMap { $0.window != nil ? $0.appState.iconDesignViewModel : nil }
    }

    /// 현재 key window에 연결된 AppState를 반환한다. 줌 등 전역 커맨드에서 사용.
    var keyWindowAppState: AppState? {
        guard let keyWindow = NSApp.keyWindow else { return nil }
        return entries.first { $0.window === keyWindow }?.appState
    }

    // MARK: - Private

    private func purgeClosedEntries() {
        entries.removeAll { $0.window == nil }
    }
}
