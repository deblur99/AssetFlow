//
//  ToolExtraButton.swift
//  AssetFlow
//
//  Created by 한현민 on 3/11/26.
//

import SwiftUI

/// ToolButton과 비슷하나 선택된 상태가 없는 버튼 (이미지 불러오기 버튼 등)
struct ToolExtraButton<T: ToolItem>: View {
    let tool: T
    @Binding var hoveredToolId: String?  // ToolButton을 사용하는 뷰에서, 현재 마우스 커서가 올라간 tool의 ID를 넘겨받음
    @Binding var enabledToolIds: Set<String>
    var onClicked: (T) -> Void
    
    var body: some View {
        Button { onClicked(tool) } label: {
            Image(systemName: tool.systemImage)
                .frame(width: 32, height: 32)
                .foregroundStyle(
                    enabledToolIds.contains(tool.id) ? Color.accentColor : Color.secondary
                )
                .background(
                    hoveredToolId == tool.id    // 마우스 커서가 올라간 툴
                        ? Color.gray.opacity(0.3)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tool.helpText)
        .keyboardShortcut(tool.shortcutKey, modifiers: [.command])
        .onHover { hover in
            if hover {
                withAnimation(.easeIn(duration: 0.1)) {
                    self.hoveredToolId = tool.id
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var hoveredToolId: String? = nil
    @Previewable @State var enabledToolIds: Set<String> = []
    
    VStack {
        ForEach(DrawingExtraTool.allCases) { tool in
            ToolExtraButton(
                tool: tool,
                hoveredToolId: $hoveredToolId,
                enabledToolIds: $enabledToolIds,
                onClicked: { clicked in
                    print("Clicked tool: \(clicked)")
                }
            )
        }
    }
    .frame(width: 400, height: 300, alignment: .topLeading)
    .padding(30)
}
