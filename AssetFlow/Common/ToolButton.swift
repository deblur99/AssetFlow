//
//  ToolButton.swift
//  AssetFlow
//
//  Created by 한현민 on 3/11/26.
//

import SwiftUI

// SwiftUI에서 프로토콜 속성을 받으려면 해당 프로토콜을 채택한 타입을 받는 제네릭을 쓰면 된다.
struct ToolButton<T: ToolItem>: View {
    let tool: T
    @Binding var selectedToolId: String?  // ToolButton을 사용하는 뷰에서, 현재 선택된 tool의 ID를 넘겨받음
    @Binding var hoveredToolId: String?  // ToolButton을 사용하는 뷰에서, 현재 마우스 커서가 올라간 tool의 ID를 넘겨받음
    var onSelected: ((T) -> Void)? = nil
    
    var body: some View {
        Button { onSelected?(tool) } label: {
            Image(systemName: tool.systemImage)
                .frame(width: 32, height: 32)
                .background(
                    selectedToolId == tool.id
                        ? Color.accentColor.opacity(0.18)  // 현재 선택된 툴
                        : hoveredToolId == tool.id    // 마우스 커서가 올라간 툴
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
    @Previewable @State var selectedToolId: String? = nil
    @Previewable @State var hoveredToolId: String? = nil
    
    VStack {
        ForEach(DrawingTool.allCases) { tool in
            ToolButton(
                tool: tool,
                selectedToolId: $selectedToolId,
                hoveredToolId: $hoveredToolId,
                onSelected: { selected in
                    selectedToolId = selected.id
                    print("Selected tool: \(selected)")
                }
            )
        }
    }
    .frame(width: 400, height: 300, alignment: .topLeading)
    .padding(30)
}
