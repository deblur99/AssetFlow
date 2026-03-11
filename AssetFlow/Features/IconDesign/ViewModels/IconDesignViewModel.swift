import SwiftUI
import UniformTypeIdentifiers

// MARK: - Active transform session

enum ActiveTransform {
    case moving(startFrame: CGRect, startPoint: CGPoint)
    case movingGroup(startFrames: [UUID: CGRect], startPoint: CGPoint)
    case resizing(handle: ResizeHandle, startFrame: CGRect, startPoint: CGPoint, startRotation: Double, anchorCanvas: CGPoint)
    case rotating(startMouseAngle: Double, startElementRotation: Double, center: CGPoint)
}

// MARK: - ViewModel

@Observable
@MainActor
final class IconDesignViewModel {

    // MARK: - Project
    var project = IconProject()

    // MARK: - Tool state
    var selectedToolId: String? = nil
    var selectedTool: DrawingTool {
        get {
            guard let selectedToolId else { return .move }
            return DrawingTool(rawValue: selectedToolId) ?? .move
        } set {
            selectedToolId = newValue.id
        }
    }
    
    var hoveredToolId: String? = nil
    var hoveredTool: DrawingTool? {
        get {
            guard let hoveredToolId else { return nil }
            return DrawingTool(rawValue: hoveredToolId)
        } set {
            hoveredToolId = newValue?.id
        }
    }
    
    /// 다중 선택된 요소 ID 집합. 단일 선택 시에도 여기에 1개 들어간다.
    var selectedElementIds: Set<UUID> = []

    /// 단일 선택 편의 프로퍼티. 정확히 1개 선택된 경우에만 non-nil.
    var selectedElementId: UUID? {
        selectedElementIds.count == 1 ? selectedElementIds.first : nil
    }

    // MARK: - Active drawing (in-progress, not yet committed)
    var activePathPoints: [CGPoint] = []
    var activeDragStart: CGPoint?
    var activeDragCurrent: CGPoint?

    // MARK: - Active transform session
    var activeTransform: ActiveTransform?

    /// 직전에 드래그로 생성된 요소 ID. 생성 직후 드래그로 위치 조정 허용에 사용.
    var justCreatedElementId: UUID?

    // MARK: - Current style
    var fillColor: Color   = Color(red: 0.20, green: 0.47, blue: 0.95)
    var strokeColor: Color = .clear
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 0
    var currentOpacity: Double = 1.0

    // MARK: - Text style defaults
    var textFontName: String = "Helvetica"
    var textFontSize: CGFloat = 100
    var textIsBold: Bool = false
    var textIsItalic: Bool = false
    var textColor: Color = .black
    var textAlignment: TextAlignmentOption = .left

    // MARK: - Text editing state
    /// 현재 인라인 편집기가 열려 있는 텍스트 요소 ID. nil이면 편집기가 닫혀 있음.
    var editingTextElementId: UUID? = nil

    // MARK: - Viewport
    var zoom: CGFloat = 1.0
    var canvasOffset: CGSize = .zero

    // MARK: - Undo / Redo
    private var undoStack: [[CanvasElement]] = []
    private var redoStack: [[CanvasElement]] = []
    private let maxUndoCount = 50
    
    // MARK: - Zoom Threshold
    private let maxZoomRatio = 10.0 // 1000%
    private let minZoomRatio = 0.05 // 5%
    static let zoomPickerLevels: [CGFloat] = [
        8.0, 4.0, 2.0, 1.5, 1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1
    ]
    
    // MARK: - Tip banner
    
    var isTipBannerPresented = false
    
    // MARK: - Computed helpers

    var elements: [CanvasElement] { project.elements }

    var selectedElement: CanvasElement? {
        guard let id = selectedElementId else { return nil }
        return project.elements.first { $0.id == id }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // MARK: - Initialization
    
    func initViewModel() {
        // TODO: 임시 처리: 이후 툴팁 언제 띄울지 결정되면 코드 수정
        isTipBannerPresented = true
    }
    
    
    // MARK: - Edit Metadata
    
    func renameProject(_ newName: String) {
        project.name = newName
        project.updatedAt = Date()
    }

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
                justCreatedElementId = nil  // 새 도형 그리기 시작 시 플래그 소거
                activeDragStart = point
            }
            activeDragCurrent = point

        case .move, .select, .text:
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
            if let id = project.elements.last?.id { selectedElementIds = [id] }

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
            if let id = project.elements.last?.id {
                selectedElementIds = [id]
                justCreatedElementId = id
            }
            selectedTool = .select

        case .move, .select, .text:
            break
        }
    }

    func handleTap(at point: CGPoint) {
        // 이동 모드에서는 선택 불가
        guard selectedTool != .move else { return }
        let hit = project.elements.reversed().first {
            $0.isVisible && $0.containsPoint(point)
        }
        selectedElementIds = hit.map { [$0.id] } ?? []
    }

    /// 마키 사각형 안에 있는 요소들을 일괄 선택한다 (선택 모드 전용).
    func applyMarqueeSelection(in rect: CGRect) {
        let ids = project.elements.filter { el in
            el.isVisible && rect.intersects(el.frame)
        }.map(\.id)
        selectedElementIds = Set(ids)
    }

    // MARK: - Zoom

    func zoomIn()    { zoom = min(zoom * 1.25, maxZoomRatio) }
    func zoomOut()   { zoom = max(zoom / 1.25, minZoomRatio) }
    func resetZoom() { zoom = 1.0 }

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
        selectedElementIds = []
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project.elements)
        project.elements = next
    }

    // MARK: - Transform: public entry points

    func beginTransform() {
        checkpoint()
    }

    /// Move / resize – updates the element's frame in canvas space.
    func setElementFrame(id: UUID, frame newFrame: CGRect) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        switch project.elements[idx] {
        case .shape(var e):
            e.frame = newFrame
            project.elements[idx] = .shape(e)
        case .image(var e):
            e.frame = newFrame
            project.elements[idx] = .image(e)
        case .path(var e):
            // For paths, translate all points to follow the new origin
            let dx = newFrame.minX - e.frame.minX
            let dy = newFrame.minY - e.frame.minY
            e.points = e.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            project.elements[idx] = .path(e)
        case .text(var e):
            e.frame = newFrame
            project.elements[idx] = .text(e)
        }
        project.updatedAt = Date()
    }
    func setElementRotation(id: UUID, rotation: Double) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        project.elements[idx].rotation = rotation
        project.updatedAt = Date()
    }

    /// Batch-update any combination of transform properties.
    func setElementTransform(id: UUID,
                              x: CGFloat?    = nil,
                              y: CGFloat?    = nil,
                              width: CGFloat? = nil,
                              height: CGFloat? = nil,
                              rotation: Double? = nil) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        let old = project.elements[idx].frame
        let newFrame = CGRect(
            x:      x      ?? old.minX,
            y:      y      ?? old.minY,
            width:  max(1, width  ?? old.width),
            height: max(1, height ?? old.height)
        )
        checkpoint()
        setElementFrame(id: id, frame: newFrame)
        if let r = rotation { setElementRotation(id: id, rotation: r) }
    }

    // MARK: - Element style editing

    func updateSelectedStyle(
        fillColor:    Color?   = nil,
        strokeColor:  Color?   = nil,
        strokeWidth:  CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        opacity:      Double?  = nil
    ) {
        guard let id = selectedElementId,
              let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        switch project.elements[idx] {
        case .shape(var e):
            if let v = fillColor    { e.fillColor    = v }
            if let v = strokeColor  { e.strokeColor  = v }
            if let v = strokeWidth  { e.strokeWidth  = v }
            if let v = cornerRadius { e.cornerRadius = v }
            if let v = opacity      { e.opacity      = v }
            project.elements[idx] = .shape(e)
        case .path(var e):
            if let v = fillColor   { e.color     = v }
            if let v = strokeColor { e.color     = v }
            if let v = strokeWidth { e.lineWidth = v }
            if let v = opacity     { e.opacity   = v }
            project.elements[idx] = .path(e)
        case .image(var e):
            if let v = opacity { e.opacity = v }
            project.elements[idx] = .image(e)
        case .text(var e):
            if let v = opacity { e.opacity = v }
            project.elements[idx] = .text(e)
        }
        project.updatedAt = Date()
    }

    // MARK: - Text element management

    func createTextElement(at point: CGPoint) {
        checkpoint()
        // 초기 높이: 정확한 폰트 메트릭으로 한 줄 높이
        let nsFont = NSFont(name: textFontName, size: textFontSize)
            ?? NSFont.systemFont(ofSize: textFontSize)
        let lineH = ceil(nsFont.ascender - nsFont.descender + nsFont.leading)
        // origin = 클릭 지점(좌측 상단). 세로 중앙은 ascender/descender로 자동 결정됨.
        // 초기 너비는 0 — reportSize가 즉시 실제 크기로 갱신함
        let frame = CGRect(x: point.x, y: point.y, width: 0, height: lineH)
        let el = TextElement(
            id: UUID(),
            name: "Text \(project.elements.count + 1)",
            frame: frame,
            text: "",
            fontName: textFontName,
            fontSize: textFontSize,
            isBold: textIsBold,
            isItalic: textIsItalic,
            textColor: textColor,
            alignment: textAlignment)
        project.addElement(.text(el))
        if let id = project.elements.last?.id {
            selectedElementIds = [id]
            editingTextElementId = id
        }
        project.updatedAt = Date()
    }

    /// 인라인 편집기에서 측정된 크기(캔버스 좌표계)로 텍스트 요소 frame을 갱신한다.
    /// checkpoint 없이 직접 갱신 — 타이핑마다 undo 스택을 쌓지 않음.
    func updateTextFrame(id: UUID, canvasSize: CGSize) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              case .text(var e) = project.elements[idx] else { return }
        e.frame = CGRect(origin: e.frame.origin, size: canvasSize)
        project.elements[idx] = .text(e)
    }

    func beginTextEdit(id: UUID) {
        guard project.elements.first(where: { $0.id == id }) != nil else { return }
        editingTextElementId = id
    }

    func endTextEdit() {
        // 빈 텍스트 요소는 자동 삭제
        if let id = editingTextElementId,
           let el = project.elements.first(where: { $0.id == id }),
           case .text(let t) = el, t.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            deleteElement(id: id)
        }
        editingTextElementId = nil
        // 편집 종료와 동시에 선택도 해제 — "포커스" 상태로 남지 않도록
        selectedElementIds = []
    }

    func updateTextContent(id: UUID, text: String) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              case .text(var e) = project.elements[idx] else { return }
        e.text = text
        project.elements[idx] = .text(e)
        project.updatedAt = Date()
    }

    /// 선택된 모든 텍스트 요소의 타이포그래피 속성을 일괄 업데이트한다.
    func updateSelectedTextStyle(
        fontName:  String?              = nil,
        fontSize:  CGFloat?             = nil,
        isBold:    Bool?                = nil,
        isItalic:  Bool?                = nil,
        textColor: Color?               = nil,
        alignment: TextAlignmentOption? = nil
    ) {
        checkpoint()
        for id in selectedElementIds {
            guard let idx = project.elements.firstIndex(where: { $0.id == id }),
                  case .text(var e) = project.elements[idx] else { continue }
            e.show()
            if let v = fontName  { e.fontName  = v }
            if let v = fontSize  { e.fontSize  = v }
            if let v = isBold    { e.isBold    = v }
            if let v = isItalic  { e.isItalic  = v }
            if let v = textColor { e.textColor = v }
            if let v = alignment { e.alignment = v }
            e.show()
            project.elements[idx] = .text(e)
        }
        // 기본값도 함께 업데이트
        if let v = fontName  { textFontName  = v }
        if let v = fontSize  { textFontSize  = v }
        if let v = isBold    { textIsBold    = v }
        if let v = isItalic  { textIsItalic  = v }
        if let v = textColor { self.textColor = v }
        if let v = alignment { textAlignment = v }
        project.updatedAt = Date()
    }

    // MARK: - Clipboard
    private var clipboard: CanvasElement?

    func copySelectedElement() {
        clipboard = selectedElement
    }

    func pasteElement() {
        guard let element = clipboard else { return }
        checkpoint()
        project.addElement(element.duplicated())
        if let id = project.elements.last?.id { selectedElementIds = [id] }
    }

    func deleteSelectedElements() {
        guard !selectedElementIds.isEmpty else { return }
        checkpoint()
        for id in selectedElementIds { project.removeElement(id: id) }
        selectedElementIds = []
    }

    func deleteSelectedElement() {
        deleteSelectedElements()
    }

    func deleteElement(id: UUID) {
        checkpoint()
        selectedElementIds.remove(id)
        project.removeElement(id: id)
    }

    /// 여러 요소의 프레임을 한 번에 업데이트한다 (그룹 이동 시 사용).
    func setElementsFrames(_ frames: [UUID: CGRect]) {
        for (id, frame) in frames { setElementFrame(id: id, frame: frame) }
    }

    func toggleVisibility(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        project.elements[idx].isVisible.toggle()
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
        if let id = project.elements.last?.id { selectedElementIds = [id] }
    }

    // MARK: - Private helpers

    func checkpoint() {
        undoStack.append(project.elements)
        if undoStack.count > maxUndoCount { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func resetActiveDrawing() {
        activeDragStart   = nil
        activeDragCurrent = nil
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
