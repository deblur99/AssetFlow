import SwiftUI

struct IconDesignView: View {
    @State private var vm = IconDesignViewModel()

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(vm.project.name)
        .toolbar {
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

                Text("\(Int(vm.zoom * 100))%")
                    .monospacedDigit()
                    .frame(minWidth: 48)

                Button { vm.zoomIn() } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom In")

                Button { vm.resetZoom() } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Reset Zoom (100%)")
            }
        }
        .onKeyPress(.delete) {
            vm.deleteSelectedElement()
            return .handled
        }
    }
}
