import AppKit
import SwiftUI

// MARK: - FocusedValues

extension FocusedValues {
    @Entry var iconDesignVM: IconDesignViewModel? = nil
}

// MARK: - Window registrar

/// SwiftUI WindowGroup 창을 NewProjectWindowManager 레지스트리에 등록하는 헬퍼 뷰.
/// NSView.viewDidMoveToWindow() 타이밍을 이용해 NSWindow 참조를 안정적으로 획득한다.
private struct WindowRegistrar: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> RegistrarView {
        RegistrarView(appState: appState)
    }

    func updateNSView(_ nsView: RegistrarView, context: Context) {}

    final class RegistrarView: NSView {
        let appState: AppState

        init(appState: AppState) {
            self.appState = appState
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            Task { @MainActor in
                NewProjectWindowManager.shared.registerWindow(window, appState: self.appState)
            }
        }
    }
}

// MARK: - New Project 커맨드

struct NewProjectCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                NewProjectWindowManager.shared.open()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}

// MARK: - File 조작 커맨드

struct ProjectFileCommands: Commands {
    @FocusedValue(\.iconDesignVM) private var vm: IconDesignViewModel?

    var body: some Commands {
        CommandGroup(replacing: .saveItem) { }

        CommandGroup(after: .newItem) {
            Divider()

            Button("Close Window") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: [.command])

            Divider()

            Button("Save Project") {
                guard let vm else { return }
                Task {
                    await ProjectFileService.saveProject(vm.project)
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Open Project…") {
                guard let vm else { return }
                Task {
                    if let project = await ProjectFileService.openProject() {
                        // 동일 프로젝트 ID의 창이 이미 열려 있으면 해당 창으로 포커스만 이동한다.
                        if !NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                            vm.loadProject(project)
                        }
                    }
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button("Export…") {
                guard let vm else { return }
                ExportService.export(vm: vm)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Rename Project…") {
                guard let vm else { return }
                let alert = NSAlert()
                alert.messageText = "Rename Project"
                alert.addButton(withTitle: "Rename")
                alert.addButton(withTitle: "Cancel")
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
                field.stringValue = vm.project.name
                alert.accessoryView = field
                alert.window.initialFirstResponder = field
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                let newName = field.stringValue.trimmingCharacters(in: .whitespaces)
                if !newName.isEmpty { vm.renameProject(newName) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

// MARK: - App entry point

@main
struct AssetFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
                .background(WindowRegistrar(appState: appState))
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    ProjectFileService.saveAutosave(
                        appState.iconDesignViewModel.project)
                }
        }
        .defaultSize(
            width: NSScreen.main?.visibleFrame.width ?? 1080,
            height: NSScreen.main?.visibleFrame.height ?? 800
        )
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        // SwiftUI WindowGroup이 외부 파일 오픈 이벤트를 처리하지 않도록 한다.
        // Finder 등에서 열린 파일은 AppDelegate.application(_:open:)이 직접 처리한다.
        .handlesExternalEvents(matching: [])
        .commands {
            NewProjectCommands()
            ProjectFileCommands()

            CommandGroup(before: .toolbar) {
                Button("Zoom In") {
                    appState.iconDesignZoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out") {
                    appState.iconDesignZoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
