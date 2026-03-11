//
//  ToolItem.swift
//  AssetFlow
//
//  Created by 한현민 on 3/11/26.
//

import SwiftUI

/// 선택 가능한 도구 항목을 나타내는 열거형이 준수하는 프로토콜
nonisolated protocol ToolItem: CaseIterable, Identifiable, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool
    
    var id: String { get }
    
    var systemImage: String { get }
    
    var shortcutKey: KeyEquivalent { get }
    
    var helpText: String { get }
}
    
nonisolated extension ToolItem {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
