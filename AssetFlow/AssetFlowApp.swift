import AppKit
import SwiftUI

// MARK: - FocusedValues

extension FocusedValues {
    @Entry var iconDesignVM: IconDesignViewModel? = nil
}

// MARK: - New Project 커맨드

struct NewProjectCommands: Commands {
    @FocusedValue(\.iconDesignVM) private var vm: IconDesignViewModel?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                showNewProjectDialog(currentVM: vm)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Open PNG as Project…") {
                Task {
                    if let project = await ProjectFileService.openPNGAsProject() {
                        NewProjectWindowManager.shared.open(with: project)
                    }
                }
            }
        }
    }

    @MainActor
    private func showNewProjectDialog(currentVM: IconDesignViewModel?) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "새 프로젝트를 어떻게 시작하시겠습니까?"
        alert.addButton(withTitle: "저장하고 현재 창에서 시작")  // .alertFirstButtonReturn
        alert.addButton(withTitle: "저장하지 않고 현재 창에서 시작")  // .alertSecondButtonReturn
        alert.addButton(withTitle: "새 창에서 시작")  // .alertThirdButtonReturn
        alert.addButton(withTitle: "취소")  // .default
        alert.buttons[3].keyEquivalent = "\u{1b}"  // Escape 키를 취소 버튼에 매핑

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard let vm = currentVM else {
                NewProjectWindowManager.shared.open()
                return
            }
            Task { @MainActor in
                if await ProjectFileService.saveProject(vm.project) {
                    vm.markSavedToFile()
                    vm.resetToNewProject()
                }
            }
        case .alertSecondButtonReturn:
            currentVM?.resetToNewProject() ?? NewProjectWindowManager.shared.open()
        case .alertThirdButtonReturn:
            NewProjectWindowManager.shared.open()
        default:  // 새 창에서 시작
            break
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
                    if await ProjectFileService.saveProject(vm.project) {
                        vm.markSavedToFile()
                    }
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Open Project…") {
                guard let vm else { return }
                Task {
                    guard let project = await ProjectFileService.openProject() else { return }

                    // 이미 열려 있는 창이면 포커스만 이동
                    if NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) { return }

                    // 현재 창에 프로젝트가 있으면 어디서 열지 묻는다
                    let alert = NSAlert()
                    alert.alertStyle = .informational
                    alert.messageText = "'\(project.name)'을(를) 어디서 여시겠습니까?"
                    alert.addButton(withTitle: "새 창에서 열기")       // .alertFirstButtonReturn
                    alert.addButton(withTitle: "현재 창에서 열기")      // .alertSecondButtonReturn
                    alert.addButton(withTitle: "취소")                 // .alertThirdButtonReturn

                    switch alert.runModal() {
                    case .alertFirstButtonReturn:
                        NewProjectWindowManager.shared.open(with: project, fromFile: true)
                    case .alertSecondButtonReturn:
                        vm.loadProject(project)
                        vm.markSavedToFile()
                    default:
                        break
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

    var body: some Scene {
        // WindowGroup은 SwiftUI 커맨드 시스템 연결 목적으로만 사용한다.
        // 실제 창 관리는 AppDelegate(AppKit)에서 전담하므로, 콘텐츠는 invisible placeholder.
        WindowGroup {
            Color.clear
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .commands {
            NewProjectCommands()
            ProjectFileCommands()

            CommandGroup(before: .toolbar) {
                Button("Zoom In") {
                    if let appState = NewProjectWindowManager.shared.keyWindowAppState {
                        appState.iconDesignZoomIn()
                    }
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out") {
                    if let appState = NewProjectWindowManager.shared.keyWindowAppState {
                        appState.iconDesignZoomOut()
                    }
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
