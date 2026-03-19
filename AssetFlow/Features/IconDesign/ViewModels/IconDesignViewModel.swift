import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export types

enum ExportFormat: String, CaseIterable, Identifiable {
    case png  = "PNG"
    case jpeg = "JPEG"
    case svg  = "SVG"
    case pdf  = "PDF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .png:  "png"
        case .jpeg: "jpg"
        case .svg:  "svg"
        case .pdf:  "pdf"
        }
    }

    var utType: UTType {
        switch self {
        case .png:  .png
        case .jpeg: .jpeg
        case .svg:  UTType(filenameExtension: "svg") ?? .image
        case .pdf:  .pdf
        }
    }
}

enum ExportSize: String, CaseIterable, Identifiable {
    case ios     = "1024 × 1024"
    case watchOS = "1088 × 1088"
    case tvOS    = "800 × 480"

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .ios:     CGSize(width: 1024, height: 1024)
        case .watchOS: CGSize(width: 1088, height: 1088)
        case .tvOS:    CGSize(width: 800,  height: 480)
        }
    }

    var subtitle: String {
        switch self {
        case .ios:     "iOS, iPadOS, macOS, visionOS"
        case .watchOS: "watchOS"
        case .tvOS:    "tvOS"
        }
    }
}

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
    // MARK: - Canvas state (프로젝트별 데이터 집합)

    /// 현재 열려 있는 프로젝트의 캔버스 상태.
    /// `canvasState.id == canvasState.project.id`로 고유하게 식별된다.
    var canvasState: CanvasState = CanvasState() {
        didSet { scheduleAutosave() }
    }

    // MARK: - New project flag

    /// true이면 `initViewModel()` 호출 시 autosave를 복원하지 않고 새 프로젝트를 유지한다.
    private let isNew: Bool

    init(isNew: Bool = false) {
        self.isNew = isNew
    }

    // MARK: - Canvas state forwarding

    /// 현재 프로젝트 데이터. `canvasState.project`로 위임된다.
    var project: IconProject {
        get { canvasState.project }
        set { canvasState.project = newValue }
    }

    /// 뷰포트 줌 배율. `canvasState.zoom`으로 위임된다.
    var zoom: CGFloat {
        get { canvasState.zoom }
        set { canvasState.zoom = newValue }
    }

    /// 캔버스 패닝 오프셋. `canvasState.canvasOffset`으로 위임된다.
    var canvasOffset: CGSize {
        get { canvasState.canvasOffset }
        set { canvasState.canvasOffset = newValue }
    }

    /// 다중 선택된 요소 ID 집합. `canvasState.selectedElementIds`로 위임된다.
    var selectedElementIds: Set<UUID> {
        get { canvasState.selectedElementIds }
        set { canvasState.selectedElementIds = newValue }
    }

    /// 인라인 텍스트 편집기가 열린 요소 ID. `canvasState.editingTextElementId`로 위임된다.
    var editingTextElementId: UUID? {
        get { canvasState.editingTextElementId }
        set { canvasState.editingTextElementId = newValue }
    }

    /// 클립보드. `canvasState.clipboard`로 위임된다.
    var clipboard: CanvasElement? {
        get { canvasState.clipboard }
        set { canvasState.clipboard = newValue }
    }

    private var undoStack: [[CanvasElement]] {
        get { canvasState.undoStack }
        set { canvasState.undoStack = newValue }
    }

    private var redoStack: [[CanvasElement]] {
        get { canvasState.redoStack }
        set { canvasState.redoStack = newValue }
    }

    // MARK: - Tool state

    var selectedToolId: String?
    var selectedTool: DrawingTool {
        get {
            guard let selectedToolId else { return .move }
            return DrawingTool(rawValue: selectedToolId) ?? .move
        } set {
            selectedToolId = newValue.id
        }
    }

    /// 도형 생성 후 select로 자동 전환될 때 복원용으로 저장되는 이전 그리기 도구.
    /// 사용자가 직접 도구를 선택하면 nil로 초기화.
    var previousDrawingTool: DrawingTool?

    /// 사용자가 직접 도구를 선택할 때 호출. previousDrawingTool을 초기화한다.
    func selectTool(_ tool: DrawingTool) {
        previousDrawingTool = nil
        selectedTool = tool
    }

    var hoveredToolId: String?
    var hoveredTool: DrawingTool? {
        get {
            guard let hoveredToolId else { return nil }
            return DrawingTool(rawValue: hoveredToolId)
        } set {
            hoveredToolId = newValue?.id
        }
    }

    var enabledToolIds: Set<String> = []

    func toggleEnabledToolId(_ tool: any ToolItem) {
        if !enabledToolIds.contains(tool.id) {
            enabledToolIds.insert(tool.id)
        } else {
            enabledToolIds.remove(tool.id)
        }

        // 격자 토글 여부도 같이 관리
        if let tool = tool as? DrawingExtraTool, tool == .showGrid {
            isGridEnabled = enabledToolIds.contains(tool.id)
        }
    }

    /// 단일 선택 편의 프로퍼티. 정확히 1개 선택된 경우에만 non-nil.
    var selectedElementId: UUID? {
        selectedElementIds.count == 1 ? selectedElementIds.first : nil
    }

    // MARK: - Active drawing (in-progress, not yet committed)

    var activePathPoints: [CGPoint] = []
    var activeDragStart: CGPoint?
    var activeDragCurrent: CGPoint?

    // MARK: - Export state

    var exportFormat: ExportFormat = .png
    var exportSize: ExportSize = .ios

    // MARK: - Active transform session

    var activeTransform: ActiveTransform?

    /// 직전에 드래그로 생성된 요소 ID. 생성 직후 드래그로 위치 조정 허용에 사용.
    var justCreatedElementId: UUID?

    // MARK: - Current style

    var fillColor: Color = .init(red: 0.20, green: 0.47, blue: 0.95)
    var strokeColor: Color = .white
    var lineWidth: CGFloat = 2
    var cornerRadii: CornerRadii = CornerRadii()
    var currentOpacity: Double = 1.0
    var smoothPath: Bool = true

    // MARK: - Text style defaults

    var textFontName: String = "Helvetica"
    var textFontSize: CGFloat = 100
    var textIsBold: Bool = false
    var textIsItalic: Bool = false
    var textColor: Color = .black

    // MARK: - Text editing state

    // MARK: - Viewport

    // MARK: - Undo / Redo

    private let maxUndoCount = 50

    // MARK: - Autosave

    private var autosaveTask: Task<Void, Never>?

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            ProjectFileService.saveAutosave(self.project)
        }
    }

    // MARK: - Zoom Threshold

    private let maxZoomRatio = 10.0 // 1000%
    private let minZoomRatio = 0.05 // 5%
    static let zoomPickerLevels: [CGFloat] = [
        8.0, 4.0, 2.0, 1.5, 1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1
    ]

    // MARK: - Tip banner

    var isTipBannerPresented = false

    // MARK: - Grid

    static let gridSize: CGFloat = 41.0
    var isGridEnabled = true // 초기 상태는 격자 표시 ON

    // MARK: - Computed helpers

    var elements: [CanvasElement] { project.elements }

    var selectedElement: CanvasElement? {
        guard let id = selectedElementId else { return nil }
        return project.elements.first { $0.id == id }
    }

    var canUndo: Bool { canvasState.canUndo }
    var canRedo: Bool { canvasState.canRedo }

    // MARK: - Auto-save

    private var autoSaveTask: Task<Void, Never>?

    /// 마지막 호출로부터 2초 뒤 자동 저장을 실행한다 (debounce).
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let snapshot = self.project
            Task.detached(priority: .utility) {
                await AutoSaveService.save(project: snapshot)
            }
        }
    }
    
    // MARK: - Clipboard

    // MARK: - Initialization

    func initViewModel() {
        // TODO: 임시 처리: 이후 툴팁 언제 띄울지 결정되면 코드 수정
        isTipBannerPresented = true
        // 새 프로젝트 모드면 autosave를 복원하지 않고 현재 빈 프로젝트를 그대로 유지한다.
        if !isNew, let saved = AutoSaveService.load() {
            loadProject(saved)
        }
    }

    // MARK: - Edit Metadata

    func renameProject(_ newName: String) {
        project.name = newName
        project.updatedAt = Date()
        scheduleAutoSave()
    }

    /// 불러온 프로젝트로 캔버스 상태를 교체한다.
    /// 새 프로젝트의 ID(`newProject.id`)를 기준으로 새 `CanvasState`가 생성된다.
    func loadProject(_ newProject: IconProject) {
        canvasState = CanvasState(project: newProject)
    }

    func renameElement(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        switch project.elements[idx] {
        case .shape(var e): e.name = trimmed; project.elements[idx] = .shape(e)
        case .path(var e):  e.name = trimmed; project.elements[idx] = .path(e)
        case .image(var e): e.name = trimmed; project.elements[idx] = .image(e)
        case .text(var e):  e.name = trimmed; project.elements[idx] = .text(e)
        case .symbol(var e): e.name = trimmed; project.elements[idx] = .symbol(e)
        case .background:   break  // Background name is fixed
        }
        project.updatedAt = Date()
    }

    // MARK: - Zoom

    func zoomIn() { zoom = min(zoom * 1.25, maxZoomRatio) }
    func zoomOut() { zoom = max(zoom / 1.25, minZoomRatio) }
    func resetZoom() { zoom = 1.0 }

    func zoomToFit(in viewportSize: CGSize) {
        let padding: CGFloat = 40
        let availableWidth = viewportSize.width - padding * 2
        let availableHeight = viewportSize.height - padding * 2
        guard availableWidth > 0, availableHeight > 0 else { return }
        let fitZoom = min(availableWidth / project.canvasSize.width,
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


    // MARK: - Element style editing

    /// strokeColor의 "투명(비활성)" 여부 판단 — alpha ≈ 0 이면 "no stroke"
    static func colorIsTransparent(_ color: Color) -> Bool {
        guard let nc = NSColor(color).usingColorSpace(.sRGB) else { return false }
        return nc.alphaComponent < 0.01
    }

    // MARK: - Path Smoothing (Ramer–Douglas–Peucker)

    private func perpendicularDistance(_ p: CGPoint, from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let len = sqrt(dx*dx + dy*dy)
        guard len > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        return abs(dy * p.x - dx * p.y + b.x * a.y - b.y * a.x) / len
    }

//    private func simplifyPath(_ points: [CGPoint], epsilon: CGFloat = 1.5) -> [CGPoint] {
    private func simplifyPath(_ points: [CGPoint], epsilon: CGFloat = 2.0) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var maxDist: CGFloat = 0
        var maxIdx = 0
        let first = points.first!, last = points.last!
        for i in 1..<points.count - 1 {
            let d = perpendicularDistance(points[i], from: first, to: last)
            if d > maxDist { maxDist = d; maxIdx = i }
        }
        if maxDist > epsilon {
            let left  = simplifyPath(Array(points[0...maxIdx]), epsilon: epsilon)
            let right = simplifyPath(Array(points[maxIdx...]),  epsilon: epsilon)
            return Array(left.dropLast()) + right
        }
        return [first, last]
    }

    // MARK: - Style Update

    func updateSelectedStyle(
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        strokeWidth: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        cornerRadii: CornerRadii? = nil,
        opacity: Double? = nil
    ) {
        guard !selectedElementIds.isEmpty else { return }
        var changed = false
        for id in selectedElementIds {
            guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { continue }
            switch project.elements[idx] {
            case .shape(var e):
                if let v = fillColor    { e.fillColor = v }
                if let v = strokeColor  {
                    e.strokeColor = v
                    // 투명(비활성) 색상 → 너비 0으로 스트로크 비활성화
                    // 불투명 색상이고 현재 너비가 0 → 기본 너비로 스트로크 활성화
                    if Self.colorIsTransparent(v) {
                        e.strokeWidth = 0
                    } else if e.strokeWidth == 0 {
                        e.strokeWidth = max(lineWidth, 1)
                    }
                }
                if let v = strokeWidth  { e.strokeWidth = v }
                if let v = cornerRadius { e.cornerRadii = CornerRadii(v) }
                if let v = cornerRadii  { e.cornerRadii = v }
                if let v = opacity      { e.opacity = v }
                project.elements[idx] = .shape(e)
                changed = true
            case .path(var e):
                if let v = fillColor   { e.color = v }
                if let v = strokeColor { e.color = v }
                if let v = strokeWidth { e.lineWidth = v }
                if let v = opacity     { e.opacity = v }
                project.elements[idx] = .path(e)
                changed = true
            case .image(var e):
                if let v = opacity { e.opacity = v }
                project.elements[idx] = .image(e)
                changed = true
            case .symbol(var e):
                if let v = opacity { e.opacity = v }
                project.elements[idx] = .symbol(e)
                changed = true
            case .text(var e):
                if let v = opacity { e.opacity = v }
                project.elements[idx] = .text(e)
                changed = true
            case .background:
                break  // Background updated via updateBackground* methods
            }
        }
        if changed { project.updatedAt = Date() }
    }

    func updateSelectedShadow(_ config: ShadowConfig?) {
        guard !selectedElementIds.isEmpty else { return }
        for id in selectedElementIds {
            guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { continue }
            project.elements[idx].shadow = config
        }
        project.updatedAt = Date()
    }

    // MARK: - Background update

    var backgroundElement: BackgroundElement? {
        guard let first = project.elements.first, case .background(let bg) = first else { return nil }
        return bg
    }

    func updateBackgroundFillColor(_ color: Color) {
        guard let idx = project.elements.firstIndex(where: { if case .background = $0 { return true }; return false }),
              case .background(var bg) = project.elements[idx] else { return }
        bg.fillColor = color
        project.elements[idx] = .background(bg)
        project.updatedAt = Date()
        scheduleAutoSave()
    }

    func updateBackgroundGradient(_ gradient: GradientConfig?) {
        guard let idx = project.elements.firstIndex(where: { if case .background = $0 { return true }; return false }),
              case .background(var bg) = project.elements[idx] else { return }
        bg.gradient = gradient
        project.elements[idx] = .background(bg)
        project.updatedAt = Date()
        scheduleAutoSave()
    }

    func updateBackgroundOpacity(_ opacity: Double) {
        guard let idx = project.elements.firstIndex(where: { if case .background = $0 { return true }; return false }),
              case .background(var bg) = project.elements[idx] else { return }
        bg.opacity = opacity
        project.elements[idx] = .background(bg)
        project.updatedAt = Date()
        scheduleAutoSave()
    }
}

// MARK: - Drawing gestures

extension IconDesignViewModel {
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
                justCreatedElementId = nil // 새 도형 그리기 시작 시 플래그 소거
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
                handleTap(at: point) // 탭: 다른 도구와 동일하게 선택/해제 처리
                return
            }
            let rawPoints = activePathPoints
            let finalPoints = smoothPath ? simplifyPath(rawPoints) : rawPoints
            let penColor = IconDesignViewModel.colorIsTransparent(strokeColor) ? Color.black : strokeColor
            let pathEl = PathElement(
                id: UUID(),
                name: "Path \(project.elements.count + 1)",
                points: finalPoints,
                color: penColor,
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
                cornerRadii: cornerRadii
            )
            shapeEl.opacity = currentOpacity
            project.addElement(.shape(shapeEl))
            resetActiveDrawing()
            if let id = project.elements.last?.id {
                selectedElementIds = [id]
                justCreatedElementId = id
            }
            previousDrawingTool = selectedTool // 자동 전환 전 도구 기억
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
}

// MARK: - Transform: public entry points

extension IconDesignViewModel {
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
        case .symbol(var e):
            e.frame = newFrame
            project.elements[idx] = .symbol(e)
        case .path(var e):
            let oldFrame = e.frame
            let scaleX = oldFrame.width > 0 ? newFrame.width / oldFrame.width : 1
            let scaleY = oldFrame.height > 0 ? newFrame.height / oldFrame.height : 1
            e.points = e.points.map { pt in
                // bounding box 원점 기준으로 스케일 후 새 원점으로 이동
                CGPoint(
                    x: newFrame.minX + (pt.x - oldFrame.minX) * scaleX,
                    y: newFrame.minY + (pt.y - oldFrame.minY) * scaleY
                )
            }
            project.elements[idx] = .path(e)
        case .text(var e):
            // 크기 변화 비율로 fontSize 비례 조정 (높이 기준)
            if e.frame.height > 0 {
                let scale = newFrame.height / e.frame.height
                if abs(scale - 1.0) > 0.001 {
                    e.fontSize = max(6, e.fontSize * scale)
                }
            }
            // 새 너비를 기준으로 줄 바꿈 후 실제 높이를 재측정해 frame 보정
            let measured = Self.measuredTextSize(
                text: e.text, fontName: e.fontName, fontSize: e.fontSize,
                isBold: e.isBold, isItalic: e.isItalic,
                maxWidth: newFrame.width
            )
            e.frame = CGRect(origin: newFrame.origin,
                             size: CGSize(width: newFrame.width, height: measured.height))
            project.elements[idx] = .text(e)
        case .background:
            break  // Background covers the full canvas; frame is not user-resizable
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
                             x: CGFloat? = nil,
                             y: CGFloat? = nil,
                             width: CGFloat? = nil,
                             height: CGFloat? = nil,
                             rotation: Double? = nil)
    {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }) else { return }
        let old = project.elements[idx].frame
        let newFrame = CGRect(
            x: x ?? old.minX,
            y: y ?? old.minY,
            width: max(1, width ?? old.width),
            height: max(1, height ?? old.height)
        )
        checkpoint()
        setElementFrame(id: id, frame: newFrame)
        if let r = rotation { setElementRotation(id: id, rotation: r) }
    }
}

// MARK: - Text element management

extension IconDesignViewModel {
    func createTextElement(at point: CGPoint) {
        checkpoint()
        let nsFont = NSFont(name: textFontName, size: textFontSize)
            ?? NSFont.systemFont(ofSize: textFontSize)
        let lineH = ceil(nsFont.ascender - nsFont.descender + nsFont.leading)
        // 초기 크기는 최소값으로; 편집기 첫 reportSize 콜백에서 실제 크기로 즉시 갱신됨
        let frame = CGRect(x: point.x, y: point.y, width: 1, height: lineH)
        let el = TextElement(
            id: UUID(),
            name: "Text \(project.elements.count + 1)",
            frame: frame,
            text: "",
            fontName: textFontName,
            fontSize: textFontSize,
            isBold: textIsBold,
            isItalic: textIsItalic,
            textColor: textColor
        )
        project.addElement(.text(el))
        if let id = project.elements.last?.id {
            selectedElementIds = [id]
            editingTextElementId = id
        }
        project.updatedAt = Date()
    }

    /// 인라인 편집기에서 측정된 크기(캔버스 좌표계)로 텍스트 요소 frame을 갱신한다.
    /// 너비·높이 모두 텍스트 내용에 맞춰 자동 조절된다.
    func updateTextFrame(id: UUID, canvasSize: CGSize) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              case .text(var e) = project.elements[idx] else { return }
        e.frame = CGRect(origin: e.frame.origin,
                         size: CGSize(width: max(1, canvasSize.width),
                                      height: max(1, canvasSize.height)))
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
           case .text(let t) = el, t.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
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
        scheduleAutoSave()
    }

    /// 선택된 모든 텍스트 요소의 타이포그래피 속성을 일괄 업데이트한다.
    func updateSelectedTextStyle(
        fontName: String? = nil,
        fontSize: CGFloat? = nil,
        isBold: Bool? = nil,
        isItalic: Bool? = nil,
        textColor: Color? = nil
    ) {
        checkpoint()
        let affectsLayout = fontName != nil || fontSize != nil || isBold != nil || isItalic != nil
        for id in selectedElementIds {
            guard let idx = project.elements.firstIndex(where: { $0.id == id }),
                  case .text(var e) = project.elements[idx] else { continue }
            e.show()
            if let v = fontName { e.fontName = v }
            if let v = fontSize { e.fontSize = v }
            if let v = isBold { e.isBold = v }
            if let v = isItalic { e.isItalic = v }
            if let v = textColor { e.textColor = v }
            e.show()
            // 폰트 속성 변경 시 현재 너비 기준으로 높이만 재측정 (너비는 고정)
            if affectsLayout {
                let newSize = Self.measuredTextSize(
                    text: e.text, fontName: e.fontName, fontSize: e.fontSize,
                    isBold: e.isBold, isItalic: e.isItalic,
                    maxWidth: e.frame.width
                )
                e.frame = CGRect(origin: e.frame.origin,
                                 size: CGSize(width: e.frame.width, height: newSize.height))
            }
            project.elements[idx] = .text(e)
        }
        // 기본값도 함께 업데이트
        if let v = fontName { textFontName = v }
        if let v = fontSize { textFontSize = v }
        if let v = isBold { textIsBold = v }
        if let v = isItalic { textIsItalic = v }
        if let v = textColor { self.textColor = v }
        project.updatedAt = Date()
    }

    /// NSLayoutManager를 사용해 텍스트의 실제 렌더링 크기를 측정한다.
    /// - Parameter maxWidth: 텍스트 컨테이너 너비 (기본값: 무한대 = 단일 행 측정)
    static func measuredTextSize(text: String, fontName: String, fontSize: CGFloat,
                                 isBold: Bool, isItalic: Bool,
                                 maxWidth: CGFloat = .greatestFiniteMagnitude) -> CGSize
    {
        var font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        if isBold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
        if isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }

        if text.isEmpty {
            let lineH = ceil(font.ascender - font.descender + font.leading)
            return CGSize(width: 1, height: lineH)
        }
        let ts = NSTextStorage(string: text, attributes: [.font: font])
        let lm = NSLayoutManager()
        let tc = NSTextContainer(containerSize: CGSize(
            width: maxWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        ts.addLayoutManager(lm)
        lm.addTextContainer(tc)
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        return CGSize(width: ceil(used.maxX), height: ceil(used.maxY))
    }
}

// MARK: - Clipboard

extension IconDesignViewModel {
    func copySelectedElement() {
        clipboard = selectedElement
    }

    func cutSelectedElement() {
        clipboard = selectedElement
        deleteSelectedElement()
    }

    func pasteElement() {
        guard let element = clipboard else { return }
        checkpoint()
        project.addElement(element.duplicated())
        if let id = project.elements.last?.id { selectedElementIds = [id] }
    }

    func deleteSelectedElements() {
        let idsToDelete = selectedElementIds.filter { id in
            !(backgroundElement?.id == id)
        }
        guard !idsToDelete.isEmpty else { return }
        checkpoint()
        for id in idsToDelete { project.removeElement(id: id) }
        selectedElementIds = []
    }

    func deleteSelectedElement() {
        deleteSelectedElements()
    }

    func deleteElement(id: UUID) {
        guard backgroundElement?.id != id else { return }
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
              idx < project.elements.count - 1,
              !isBackgroundId(id) else { return }
        checkpoint()
        project.swapElements(at: idx, idx + 1)
    }

    func sendBackward(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              idx > lowestMovableIndex,
              !isBackgroundId(id) else { return }
        checkpoint()
        project.swapElements(at: idx, idx - 1)
    }

    func bringToFront(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              idx < project.elements.count - 1,
              !isBackgroundId(id) else { return }
        checkpoint()
        let el = project.elements.remove(at: idx)
        project.elements.append(el)
    }

    func sendToBack(id: UUID) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              idx > lowestMovableIndex,
              !isBackgroundId(id) else { return }
        checkpoint()
        let el = project.elements.remove(at: idx)
        project.elements.insert(el, at: lowestMovableIndex)
    }

    private var lowestMovableIndex: Int { backgroundElement != nil ? 1 : 0 }
    private func isBackgroundId(_ id: UUID) -> Bool { backgroundElement?.id == id }
}

// MARK: - Image import

extension IconDesignViewModel {
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
            x: (project.canvasSize.width - scaled.width) / 2,
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

    func addSymbol(name: String) {
        checkpoint()
        let side = min(project.canvasSize.width, project.canvasSize.height) * 0.4
        let size = CGSize(width: side, height: side)
        let origin = CGPoint(
            x: (project.canvasSize.width  - side) / 2,
            y: (project.canvasSize.height - side) / 2
        )
        let el = SymbolElement(
            id: UUID(),
            name: name,
            frame: CGRect(origin: origin, size: size),
            symbolName: name
        )
        project.addElement(.symbol(el))
        if let id = project.elements.last?.id { selectedElementIds = [id] }
    }

    func updateSymbolTintColor(id: UUID, color: Color) {
        guard let idx = project.elements.firstIndex(where: { $0.id == id }),
              case .symbol(var e) = project.elements[idx] else { return }
        e.tintColor = color
        project.elements[idx] = .symbol(e)
        project.updatedAt = Date()
        scheduleAutoSave()
    }
}

// MARK: - Private helpers

extension IconDesignViewModel {
    func checkpoint() {
        undoStack.append(project.elements)
        if undoStack.count > maxUndoCount { undoStack.removeFirst() }
        redoStack.removeAll()
        scheduleAutoSave()
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
