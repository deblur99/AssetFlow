import SwiftUI

// MARK: - FocusedValues — Commands에서 ViewModel에 접근하기 위한 키

extension FocusedValues {
    @Entry var iconDesignVM: IconDesignViewModel? = nil
}

// MARK: - File 메뉴 커맨드

struct AppCommands: Commands {
    @FocusedValue(\.iconDesignVM) private var vm: IconDesignViewModel?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // "New Window"를 "New Project"로 교체
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                openWindow(id: "new-project")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            // NOTE: .disabled(vm == nil)을 사용하면 앱 시작 시 vm이 nil이어서
            // SwiftUI가 CommandGroup 전체를 렌더링하지 않는 버그가 있음.
            // 대신 액션 내부에서 guard let vm으로 nil 처리.
            Button("Save Project") {
                guard let vm else { return }
                ProjectFileService.saveProject(vm.project)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Open Project…") {
                guard let vm else { return }
                ProjectFileService.openProject { vm.loadProject($0) }
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
    @State private var appState = AppState()

    var body: some Scene {
        // 메인 창 (autosave 복원)
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 600, minHeight: 400)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSApplication.willTerminateNotification)
                ) { _ in
                    ProjectFileService.saveAutosave(
                        appState.iconDesignViewModel.project)
                }
        }
        .defaultSize(width: 1080, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            AppCommands()

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

        // 새 프로젝트 창 (빈 프로젝트, autosave 무관)
        WindowGroup(id: "new-project") {
            NewProjectWindowView()
        }
        .defaultSize(width: 1080, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
