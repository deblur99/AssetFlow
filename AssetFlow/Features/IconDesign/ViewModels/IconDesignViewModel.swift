import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
final class IconDesignViewModel {

    // MARK: - Project
    var project = IconProject()

    // MARK: - Tool state
    var selectedTool: DrawingTool = .select
    var selectedElementId: UUID?

    // MARK: - Active drawing (in-progress, not yet committed)
    var activePathPoints: [CGPoint] = []
    var activeDragStart: CGPoint?
    var activeDragCurrent: CGPoint?

    // MARK: - Current style (applied when creating new elements)
    var fillColor: Color   = Color(red: 0.20, green: 0.47, blue: 0.95)
    var strokeColor: Color = .clear
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 0
    var currentOpacity: Double = 1.0

    // MARK: - Viewport
    var zoom: CGFloat = 1.0

    // MARK: - Undo / Redo
    private var undoStack: [[CanvasElement]] = []
    private var redoStack: [[CanvasElement]] = []
    private let maxUndoCount = 50

    // MARK: - Computed helpers

    var elements: [CanvasElement] { project.elements }

    var selectedElement: CanvasElement? {
        guard let id = selectedElementId else { return nil }
        return project.elements.first { $0.id == id }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Drawing gestures

    func handleDragChanged(at point: CGPoint) {
        switch selectedTool {
        case .pen:
            if activePathPoints.isEmpty {
                checkpoint()
                activePathPoints = [point]
            } else {
                activePathPoints.append(point)
            }

        case .rectangle, .ellipse:
            if activeDragStart == nil {
                checkpoint()
                activeDragStart = point
            }
            activeDragCurrent = point

        case .select:
            break
        }
    }

    func handleDragEnded(at point: CGPoint) {
        switch selectedTool {
        case .pen:
            guard activePathPoints.count > 1 else {
                activePathPoints = []
                return
            }
            let pathEl = PathElement(
                id: UUID(),
                name: "Path \(project.elements.count + 1)",
                points: activePathPoints,
                color: strokeColor == .clear ? fillColor : strokeColor,
                lineWidth: lineWidth
            )
            project.addElement(.path(pathEl))
            activePathPoints = []
            selectedElementId = project.elements.last?.id

        case .rectangle, .ellipse:
            guard let start = activeDragStart, let end = activeDragCurrent else {
                resetActiveDrawing()
                return
            }
            let rect = normalizedRect(from: start, to: end)
            guard rect.width > 2, rect.height > 2 else {
                resetActiveDrawing()
                return
            }
            var shapeEl = ShapeElement(
                id: UUID(),
                name: "\(selectedTool.rawValue) \(project.elements.count + 1)",
                frame: rect,
                shapeType: selectedTool == .rectangle ? .rectangle : .ellipse,
                fillColor: fillColor,
                strokeColor: strokeColor,
                strokeWidth: strokeColor == .clear ? 0 : lineWidth,
                cornerRadius: cornerRadius
            )
            shapeEl.opacity = currentOpacity
            project.addElement(.shape(shapeEl))
            resetActiveDrawing()
            selectedElementId = project.elements.last?.id

        case .select:
            break
        }
    }

    func handleTap(at point: CGPoint) {
        guard selectedTool == .select else { return }
        let hit = project.elements.reversed().first {
            $0.isVisible && $0.frame.insetBy(dx: -4, dy: -4).contains(point)
        }
        selectedElementId = hit?.id
    }

    // MARK: - Zoom

    func zoomIn()    { zoom = min(zoom * 1.25, 16.0) }
    func zoomOut()   { zoom = max(zoom / 1.25, 0.05) }
    func resetZoom() { zoom = 1.0 }

    /// 주어진 뷰포트 크기에 캔버스 전체가 들어오도록 zoom을 자동 조정합니다.
    func zoomToFit(in viewportSize: CGSize) {
        let padding: CGFloat = 40
        let availableWidth  = viewportSize.width  - padding * 2
        let availableHeight = viewportSize.height - padding * 2
        guard availableWidth > 0, availableHeight > 0 else { return }
        let fitZoom = min(availableWidth  / project.canvasSize.width,
                          availableHeight / project.canvasSize.height)
        zoom = max(0.05, min(fitZoom, 1.0))
    }

    // MARK: - Undo / Redo

    func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(project.elements)
        project.elements = prev
        selectedElementId = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project.elements)
        project.elements = next
    }

    // MARK: - Element management

    func deleteSelectedElement() {
        guard let id = selectedElementId else { return }
        deleteElement(id: id)
    }

    func deleteElement(id: UUID) {
        checkpoint()
        if selectedElementId == id { selectedElementId = nil }
        project.removeElement(id: id)
    }

    func toggleVisibility(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        let current = project.elements[idx].isVisible
        project.elements[idx].isVisible = !current
    }

    func bringForward(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              idx < project.elements.count - 1 else { return }
        checkpoint()
        project.swapElements(at: idx, idx + 1)
    }

    func sendBackward(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              idx > 0 else { return }
        checkpoint()
        project.swapElements(at: idx, idx - 1)
    }

    // MARK: - Image import

    func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .bmp, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url) else { return }

        checkpoint()
        let size = image.size
        let maxDim = min(project.canvasSize.width, project.canvasSize.height) * 0.6
        let scale = min(maxDim / max(size.width, size.height), 1.0)
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: (project.canvasSize.width  - scaled.width)  / 2,
            y: (project.canvasSize.height - scaled.height) / 2
        )
        let imgEl = ImageElement(
            id: UUID(),
            name: url.deletingPathExtension().lastPathComponent,
            frame: CGRect(origin: origin, size: scaled),
            image: image
        )
        project.addElement(.image(imgEl))
        selectedElementId = project.elements.last?.id
    }

    // MARK: - Private helpers

    private func checkpoint() {
        undoStack.append(project.elements)
        if undoStack.count > maxUndoCount { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func resetActiveDrawing() {
        activeDragStart = nil
        activeDragCurrent = nil
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
