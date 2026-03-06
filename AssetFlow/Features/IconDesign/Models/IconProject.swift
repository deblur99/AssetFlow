import SwiftUI

nonisolated struct IconProject: Identifiable {
    let id: UUID
    var name: String
    var canvasSize: CGSize
    var backgroundColor: Color
    var elements: [CanvasElement]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Icon",
        canvasSize: CGSize = CGSize(width: 1024, height: 1024), // 캔버스 기본 크기이나 실제로는 창 크기, 캔버스 확대 비율에 의해 자동 조절
        backgroundColor: Color = .white
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.backgroundColor = backgroundColor
        self.elements = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func addElement(_ element: CanvasElement) {
        elements.append(element)
        updatedAt = Date()
    }

    mutating func removeElement(id elementId: UUID) {
        elements.removeAll { $0.id == elementId }
        updatedAt = Date()
    }

    mutating func swapElements(at i: Int, _ j: Int) {
        guard elements.indices.contains(i), elements.indices.contains(j) else { return }
        elements.swapAt(i, j)
        updatedAt = Date()
    }
}
