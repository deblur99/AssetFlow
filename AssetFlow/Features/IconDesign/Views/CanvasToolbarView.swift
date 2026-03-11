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
                    hoveredToolId: $vm.hoveredToolId
                ) { tool in
                    vm.selectedTool = tool
                }
            }

            Divider()
                .padding(.vertical, 4)

            ForEach(DrawingExtraTool.allCases) { tool in
                ToolExtraButton(
                    tool: tool,
                    hoveredToolId: $vm.hoveredToolId
                ) { tool in
                    if tool == .imagePicker {
                        vm.importImage()
                    }
                }
            }
            
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onHover { hover in
            if !hover {
                vm.hoveredTool = nil
            }
        }
    }
}

#Preview {
    CanvasToolbarView(vm: IconDesignViewModel())
}
