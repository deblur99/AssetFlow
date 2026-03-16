import SwiftUI

// MARK: - FocusedValues

extension FocusedValues {
    @Entry var iconDesignVM: IconDesignViewModel? = nil
}

// MARK: - New Project 커맨드 (openWindow 전용)
// @Environment(\.openWindow)와 @FocusedValue를 같은 Commands 구조체에 섞으면
// macOS 26에서 일부 CommandGroup이 렌더링되지 않는 버그가 있으므로 분리.

struct NewProjectCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                // UUID를 값으로 전달해 매 호출마다 독립된 새 창을 생성한다.
                // WindowGroup(id:for:)는 같은 값이 없으면 항상 새 창을 만든다.
                openWindow(id: "new-project", value: UUID())
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}

// MARK: - File 조작 커맨드 (FocusedValue 전용)

struct ProjectFileCommands: Commands {
    @FocusedValue(\.iconDesignVM) private var vm: IconDesignViewModel?

    var body: some Commands {
        // replacing: .saveItem은 macOS 26에서 신뢰할 수 없으므로
        // after: .newItem으로 위치를 지정하고 기본 saveItem은 빈 블록으로 제거.
        CommandGroup(replacing: .saveItem) { }

        CommandGroup(after: .newItem) {
            Divider()

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

        // 새 프로젝트 창 — UUID 값을 키로 사용해 호출마다 독립된 창 생성
        // 창 상태 복원은 불필요하므로 비활성화
        WindowGroup(id: "new-project", for: UUID.self) { _ in
            NewProjectWindowView()
        }
        .defaultSize(width: 1080, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
