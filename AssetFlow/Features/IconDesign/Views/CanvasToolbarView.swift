import SwiftUI

struct CanvasToolbarView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 8)

            ForEach(DrawingTool.allCases) { tool in
                ToolButton(
                    tool: tool,
                    selectedToolId: $vm.selectedToolId,
                    hoveredToolId: $vm.hoveredToolId,
                    enabledToolIds: $vm.enabledToolIds
                ) { tool in
                    vm.selectTool(tool)
                }
            }

            Divider()
                .padding(.vertical, 4)

            ForEach(DrawingExtraTool.allCases) { tool in
                ToolExtraButton(
                    tool: tool,
                    hoveredToolId: $vm.hoveredToolId,
                    enabledToolIds: $vm.enabledToolIds
                ) { tool in
                    switch tool {
                    case .imagePicker:
                        vm.importImage()
                    case .showGrid:
                        vm.toggleEnabledToolId(tool)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onHover { hover in
            if hover {
                NSCursor.arrow.set()
            } else {
                vm.hoveredTool = nil
            }
        }
    }
}

#Preview {
    CanvasToolbarView(vm: IconDesignViewModel())
}
