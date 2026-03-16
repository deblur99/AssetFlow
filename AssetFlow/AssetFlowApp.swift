import SwiftUI

// MARK: - FocusedValues — Commands에서 ViewModel에 접근하기 위한 키

extension FocusedValues {
    @Entry var iconDesignVM: IconDesignViewModel? = nil
}

// MARK: - File 메뉴 커맨드

struct AppCommands: Commands {
    @FocusedValue(\.iconDesignVM) private var vm: IconDesignViewModel?

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save Project") {
                guard let vm else { return }
                ProjectFileService.saveProject(vm.project)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(vm == nil)

            Button("Open Project…") {
                guard let vm else { return }
                ProjectFileService.openProject { vm.loadProject($0) }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(vm == nil)

            Divider()

            Button("Export…") {
                guard let vm else { return }
                ExportService.export(vm: vm)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(vm == nil)

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
            .disabled(vm == nil)
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
            AppCommands()

            CommandGroup(before: .toolbar) {
                Button("Zoom In", systemImage: "plus.magnifyingglass") {
                    appState.iconDesignZoomIn()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                    appState.iconDesignZoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command])
            }
        }
    }
}
