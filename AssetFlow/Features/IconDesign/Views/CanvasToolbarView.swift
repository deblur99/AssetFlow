import SwiftUI

struct CanvasToolbarView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        VStack(spacing: 2) {
            Spacer().frame(height: 8)

            ForEach(DrawingTool.allCases) { tool in
                toolButton(for: tool)
            }

            Divider()
                .padding(.vertical, 4)

            // Image import (not a persistent tool mode)
            Button { vm.importImage() } label: {
                Image(systemName: "photo")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Import Image")

            Spacer()
        }
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func toolButton(for tool: DrawingTool) -> some View {
        Button { vm.selectedTool = tool } label: {
            Image(systemName: tool.systemImage)
                .frame(width: 32, height: 32)
                .background(
                    vm.selectedTool == tool
                        ? Color.accentColor.opacity(0.18)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tool.rawValue)
        .keyboardShortcut(tool.shortcutKey, modifiers: [])
    }
}
