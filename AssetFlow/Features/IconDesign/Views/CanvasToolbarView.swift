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
            
            Divider()
                .padding(.vertical, 4)

            // 격자 토글 (⌘G)
            Button {
                vm.isGridEnabled.toggle()
            } label: {
                Image(systemName: vm.isGridEnabled ? "grid" : "grid")
                    .font(.system(size: 14))
                    .foregroundStyle(vm.isGridEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(vm.isGridEnabled
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Show Grid — ⌘G")

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
