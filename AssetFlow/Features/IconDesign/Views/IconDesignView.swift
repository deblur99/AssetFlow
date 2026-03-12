import SwiftUI

struct IconDesignView: View {
    @Environment(AppState.self) private var appState
    
    private var vm: IconDesignViewModel {
        appState.iconDesignViewModel
    }
    
    @State private var isShowingRenameMenu = false
    @State private var isShowingZoomMenu = false
    @State private var isShowingExportMenu = false

    var body: some View {
        HStack(spacing: 0) {
            CanvasToolbarView(vm: vm)
                .frame(width: 52)

            Divider()
            
            DesignCanvasView(vm: vm)

            Divider()

            PropertiesPanelView(vm: vm)
                .frame(width: 240)
        }
        .navigationTitle(vm.project.name)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isShowingRenameMenu.toggle()
                } label: {
                    Image(systemName: "pencil.line")
                }
                .popover(isPresented: $isShowingRenameMenu, arrowEdge: .bottom) {
                    RenameProjectView(name: vm.project.name) { newName in
                        vm.renameProject(newName)
                        isShowingRenameMenu = false
                    }
                    .padding(12)
                }
            }
            
            ToolbarItemGroup(placement: .navigation) {
                Button { vm.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!vm.canUndo)
                .help("Undo (⌘Z)")

                Button { vm.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!vm.canRedo)
                .help("Redo (⌘⇧Z)")
            }

            ToolbarItemGroup {
                Button { vm.zoomOut() } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom Out")

                Button {
                    isShowingZoomMenu.toggle()
                } label: {
                    Text("\(Int(vm.zoom * 100))%")
                        .monospacedDigit()
                        .frame(minWidth: 48)
                }
                .popover(isPresented: $isShowingZoomMenu, arrowEdge: .bottom) {
                    ZoomPickerView(currentZoom: vm.zoom) { level in
                        vm.zoom = level
                        isShowingZoomMenu = false
                    }
                }

                Button { vm.zoomIn() } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom In")

                Button { vm.resetZoom() } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Reset Zoom (100%)")

                Divider()

                Button {
                    isShowingExportMenu.toggle()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export Icon")
                .popover(isPresented: $isShowingExportMenu, arrowEdge: .bottom) {
                    Text("Export options coming soon.")
                        .padding()
                }
            }
        }
        .onKeyPress(.delete) {
            vm.deleteSelectedElement()
            return .handled
        }
        .background {
            Group {
                Button("") { vm.copySelectedElement() }
                    .keyboardShortcut("c", modifiers: .command)
                Button("") { vm.pasteElement() }
                    .keyboardShortcut("v", modifiers: .command)
                Button("") { vm.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("") { vm.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                Button("") { vm.isGridEnabled.toggle() }
                    .keyboardShortcut("g", modifiers: .command)
            }
            .hidden()
        }
        .onAppear {
            vm.initViewModel()  // 초기에 툴팁 띄우기
        }
    }
}

private struct ZoomPickerView: View {
    let currentZoom: CGFloat
    let onSelect: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(IconDesignViewModel.zoomPickerLevels, id: \.self) { level in
                Button {
                    onSelect(level)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .opacity(abs(currentZoom - level) < 0.01 ? 1 : 0)
                            .frame(width: 12)
                        Text("\(Int(level * 100))%")
                            .monospacedDigit()
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .frame(minWidth: 100)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    IconDesignView()
        .environment(AppState())
}
