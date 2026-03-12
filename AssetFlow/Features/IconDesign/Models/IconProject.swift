import SwiftUI

nonisolated struct IconProject: Identifiable {
    let id: UUID
    var name: String
    var canvasSize: CGSize
    var elements: [CanvasElement]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Untitled Icon",
        canvasSize: CGSize = CGSize(width: 1024, height: 1024),
        backgroundColor: Color = .white
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.elements = [
            .background(BackgroundElement(id: UUID(), fillColor: backgroundColor))
        ]
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
