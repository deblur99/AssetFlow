import AppKit
import SwiftUI

struct DesignCanvasView: View {
    @Bindable var vm: IconDesignViewModel

    // Hit-test tolerance in canvas (model) coordinates
    private var handleTolerance: CGFloat { 8 / vm.zoom }
    private var rotHandleOffset: CGFloat { 24 / vm.zoom }

    @State private var lastMagnification: CGFloat = 1.0
    @State private var scrollMonitor: Any?
    @State private var isPanning = false
    @State private var panStartOffset: CGSize = .zero
    @State private var viewportSize: CGSize = .zero
    /// 선택 모드에서 드래그로 그리는 마키 사각형 (캔버스 좌표)
    @State private var marqueeRect: CGRect?
    private class HoverState { var isHovering = false }
    @State private var hoverState = HoverState()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                    .gesture(backgroundPanGesture)
                
                canvasLayer
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .contentShape(Rectangle())
                    .position(
                        x: geometry.size.width / 2 + vm.canvasOffset.width,
                        y: geometry.size.height / 2 + vm.canvasOffset.height)
                    .gesture(interactionGesture)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            cursorFor(canvasCoord(from: location)).set()
                        case .ended:
                            NSCursor.arrow.set()
                        }
                    }
                
                TipBannerView(isPresented: $vm.isTipBannerPresented)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onContinuousHover { phase in
                if case .active = phase { hoverState.isHovering = true }
                else { hoverState.isHovering = false }
            }
            .simultaneousGesture(magnifyGesture)
            .onAppear {
                    viewportSize = geometry.size
                    vm.zoomToFit(in: geometry.size)
                    setupScrollWheelZoom()
                }
                .onDisappear {
                    if let m = scrollMonitor { NSEvent.removeMonitor(m) }
                }
                .onChange(of: geometry.size) { _, s in
                    viewportSize = s
                    vm.zoomToFit(in: s)
                }
            .overlay(alignment: .bottomTrailing) {
                MinimapView(
                    canvasSize: vm.project.canvasSize,
                    zoom: vm.zoom,
                    canvasOffset: $vm.canvasOffset,
                    viewportSize: geometry.size)
                    .padding(12)
            }
        }
    }

    // MARK: - Canvas layer

    private var canvasLayer: some View {
        ZStack(alignment: .topLeading) {
            vm.project.backgroundColor

            Canvas { ctx, _ in
                let z = vm.zoom
                for element in vm.elements where element.isVisible {
                    renderElement(element, in: &ctx, zoom: z)
                }
                renderActivePreview(in: &ctx, zoom: z)
            }

            // 단일 선택: 리사이즈·회전 핸들 포함 오버레이
            if let element = vm.selectedElement {
                SelectionOverlayView(element: element, zoom: vm.zoom)
            }

            // 다중 선택: 각 요소에 단순 점선 테두리
            if vm.selectedElementIds.count > 1 {
                ForEach(vm.elements.filter { vm.selectedElementIds.contains($0.id) }) { element in
                    Rectangle()
                        .stroke(Color.accentColor,
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        .frame(width: element.frame.width * vm.zoom,
                               height: element.frame.height * vm.zoom)
                        .rotationEffect(Angle(degrees: element.rotation))
                        .position(x: element.frame.midX * vm.zoom,
                                  y: element.frame.midY * vm.zoom)
                        .allowsHitTesting(false)
                }
            }

            // 마키 선택 사각형
            if let mq = marqueeRect {
                Rectangle()
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .background(Color.accentColor.opacity(0.05))
                    .frame(width: mq.width * vm.zoom,
                           height: mq.height * vm.zoom)
                    .position(x: mq.midX * vm.zoom, y: mq.midY * vm.zoom)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: vm.project.canvasSize.width * vm.zoom,
               height: vm.project.canvasSize.height * vm.zoom)
    }
}

// MARK: - Element rendering

extension DesignCanvasView {
    private func renderElement(_ element: CanvasElement,
                               in ctx: inout GraphicsContext,
                               zoom z: CGFloat)
    {
        switch element {
        case .shape(let shape):
            let rect = scaled(shape.frame, by: z)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let path = shapePath(type: shape.shapeType, in: rect,
                                 cornerRadius: shape.cornerRadius * z)
            ctx.drawLayer { inner in
                applyRotation(to: &inner, center: center, degrees: shape.rotation)
                inner.opacity = shape.opacity
                inner.fill(path, with: .color(shape.fillColor))
                if shape.strokeWidth > 0 {
                    inner.stroke(path, with: .color(shape.strokeColor),
                                 lineWidth: shape.strokeWidth * z)
                }
            }

        case .path(let pathEl):
            guard pathEl.points.count > 1 else { return }
            let f = scaled(pathEl.frame, by: z)
            let center = CGPoint(x: f.midX, y: f.midY)
            let p = polyline(from: pathEl.points, zoom: z)
            ctx.drawLayer { inner in
                applyRotation(to: &inner, center: center, degrees: pathEl.rotation)
                inner.opacity = pathEl.opacity
                inner.stroke(p, with: .color(pathEl.color),
                             style: StrokeStyle(lineWidth: pathEl.lineWidth * z,
                                                lineCap: .round, lineJoin: .round))
            }

        case .image(let imgEl):
            let rect = scaled(imgEl.frame, by: z)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            guard let cg = imgEl.image.cgImage(forProposedRect: nil,
                                               context: nil, hints: nil) else { return }
            ctx.drawLayer { inner in
                applyRotation(to: &inner, center: center, degrees: imgEl.rotation)
                inner.opacity = imgEl.opacity
                inner.draw(Image(cg, scale: 1.0, label: Text(imgEl.name)), in: rect)
            }
        }
    }

    private func renderActivePreview(in ctx: inout GraphicsContext, zoom z: CGFloat) {
        if vm.activePathPoints.count > 1 {
            let p = polyline(from: vm.activePathPoints, zoom: z)
            let color = vm.strokeColor == .clear ? vm.fillColor : vm.strokeColor
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: vm.lineWidth * z,
                                          lineCap: .round, lineJoin: .round))
        }
        if let start = vm.activeDragStart, let end = vm.activeDragCurrent {
            let rect = scaled(normalizedRect(from: start, to: end), by: z)
            let type: ShapeElement.ShapeType = vm.selectedTool == .rectangle ? .rectangle : .ellipse
            let path = shapePath(type: type, in: rect, cornerRadius: vm.cornerRadius * z)
            ctx.fill(path, with: .color(vm.fillColor.opacity(0.6)))
            let stroke = vm.strokeColor == .clear ? Color.gray.opacity(0.6) : vm.strokeColor
            ctx.stroke(path, with: .color(stroke), lineWidth: max(1, vm.lineWidth * z))
        }
    }
}

// MARK: - Cursor

extension DesignCanvasView {
    /// 현재 커서 위치에 맞는 NSCursor를 반환합니다.
    private func cursorFor(_ pt: CGPoint) -> NSCursor {
        // 활성 변환 중엔 변환 종류에 맞는 커서
        if let t = vm.activeTransform {
            switch t {
            case .moving, .movingGroup: return .closedHand
            case .resizing(let h, _, _, let rot, _): return resizeCursor(for: h, rotation: rot)
            case .rotating: return .crosshair
            }
        }

        // 이동 모드: 선택된 요소의 핸들/바디 위면 변환 커서, 그 외엔 패닝 커서
        if vm.selectedTool == .move {
            if let el = vm.selectedElement {
                if dist(pt, rotationHandleCanvasPos(for: el)) < handleTolerance { return .dragLink }
                if let handle = edgeResizeHandle(at: pt, for: el) { return resizeCursor(for: handle, rotation: el.rotation) }
                if el.containsPoint(pt) { return .openHand }
            }
            return isPanning ? .closedHand : .openHand
        }

        if let el = vm.selectedElement {
            // 회전 핸들
            if dist(pt, rotationHandleCanvasPos(for: el)) < handleTolerance {
                return .dragLink
            }
            // 엣지 존 리사이즈
            if let handle = edgeResizeHandle(at: pt, for: el) {
                return resizeCursor(for: handle, rotation: el.rotation)
            }
            // 요소 바디 — select 도구일 때만 openHand
            if el.containsPoint(pt) && vm.selectedTool == .select {
                return .openHand
            }
        }

        // 다중 선택 상태에서 선택된 요소 위 → 이동 가능 커서
        if vm.selectedElementIds.count > 1 {
            let onSelected = vm.elements.first {
                vm.selectedElementIds.contains($0.id) && $0.containsPoint(pt)
            }
            if onSelected != nil { return .openHand }
        }

        // 현재 도구 기본 커서
        switch vm.selectedTool {
        case .move: return isPanning ? .closedHand : .openHand
        case .select: return .crosshair
        case .pen, .rectangle, .ellipse: return .crosshair
        }
    }

    private func resizeCursor(for handle: ResizeHandle, rotation: Double) -> NSCursor {
        let angle = handleScreenAngle(handle, rotation: rotation)
        let normalized = ((angle.truncatingRemainder(dividingBy: 180)) + 180)
            .truncatingRemainder(dividingBy: 180)
        if normalized < 22.5 || normalized >= 157.5 { return .resizeLeftRight }
        if normalized < 67.5 { return .crosshair }
        if normalized < 112.5 { return .resizeUpDown }
        return .crosshair
    }

    private func handleScreenAngle(_ handle: ResizeHandle, rotation: Double) -> Double {
        let base: Double
        switch handle {
        case .left, .right: base = 0
        case .top, .bottom: base = 90
        case .topLeft, .bottomRight: base = 135
        case .topRight, .bottomLeft: base = 45
        }
        return base + rotation
    }
}

// MARK: - Zoom gestures

extension DesignCanvasView {
    private var backgroundPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isPanning {
                    isPanning = true
                    panStartOffset = vm.canvasOffset
                }
                vm.canvasOffset = CGSize(
                    width: panStartOffset.width + value.translation.width,
                    height: panStartOffset.height + value.translation.height)
                NSCursor.closedHand.set()
            }
            .onEnded { _ in
                isPanning = false
                NSCursor.openHand.set()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastMagnification
                // 민감도 감쇠: delta를 1.0 기준으로 60% 수준으로 줄임
                let dampened = 1 + (delta - 1) * 0.6
                vm.zoom = max(0.05, min(vm.zoom * dampened, 16.0))
                lastMagnification = value
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    private func setupScrollWheelZoom() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [hoverState] event in
            guard hoverState.isHovering else { return event }

            if event.modifierFlags.contains(.command) {
                // cmd+스크롤: 줌
                let delta = event.scrollingDeltaY
                DispatchQueue.main.async {
                    let factor = 1.0 + delta * 0.005
                    self.vm.zoom = max(0.05, min(self.vm.zoom * factor, 16.0))
                }
                return nil
            }

            // 일반 스크롤 / 트랙패드 두 손가락 드래그: 캔버스 패닝
            let dx: CGFloat
            let dy: CGFloat
            if event.modifierFlags.contains(.shift) {
                // shift+스크롤: 수평 이동
                dx = event.scrollingDeltaY
                dy = 0
            } else {
                dx = event.scrollingDeltaX
                dy = event.scrollingDeltaY
            }
            DispatchQueue.main.async {
                self.vm.canvasOffset.width += dx
                self.vm.canvasOffset.height += dy
            }
            return nil
        }
    }
}

// MARK: - Unified interaction gesture

extension DesignCanvasView {
    private var interactionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let pt = canvasCoord(from: value.location)
                let start = canvasCoord(from: value.startLocation)

                // ── Begin phase ─────────────────────────────────────────────
                if vm.activeTransform == nil
                    && !isPanning
                    && vm.activePathPoints.isEmpty
                    && vm.activeDragStart == nil
                    && marqueeRect == nil
                {
                    // ── 이동 모드: 선택 요소 핸들/바디면 변환, 그 외엔 패닝 ────────
                    if vm.selectedTool == .move {
                        if let el = vm.selectedElement {
                            // 회전 핸들
                            let rotPos = rotationHandleCanvasPos(for: el)
                            if dist(start, rotPos) < handleTolerance {
                                let center = CGPoint(x: el.frame.midX, y: el.frame.midY)
                                let angle = atan2(start.y - center.y,
                                                  start.x - center.x) * 180 / .pi
                                vm.beginTransform()
                                vm.activeTransform = .rotating(
                                    startMouseAngle: angle,
                                    startElementRotation: el.rotation,
                                    center: center)
                                NSCursor.crosshair.set()
                                return
                            }
                            // 리사이즈 핸들
                            if let handle = edgeResizeHandle(at: start, for: el) {
                                vm.beginTransform()
                                let anchor = handle.opposite.canvasPosition(
                                    frame: el.frame, rotation: el.rotation)
                                vm.activeTransform = .resizing(
                                    handle: handle,
                                    startFrame: el.frame,
                                    startPoint: start,
                                    startRotation: el.rotation,
                                    anchorCanvas: anchor)
                                resizeCursor(for: handle, rotation: el.rotation).set()
                                return
                            }
                            // 요소 바디 → 이동
                            if el.containsPoint(start) {
                                vm.beginTransform()
                                vm.activeTransform = .moving(startFrame: el.frame, startPoint: start)
                                NSCursor.closedHand.set()
                                return
                            }
                        }
                        // 빈 영역 → 패닝
                        isPanning = true
                        panStartOffset = vm.canvasOffset
                        NSCursor.closedHand.set()
                        return
                    }

                    // ── 선택/그리기 모드 ─────────────────────────────────────
                    if let el = vm.selectedElement {
                        // 제스처 타입은 시작 위치(start)로 판정한다
                        // (현재 위치 pt는 DragGesture 첫 콜백 시 이미 이동했을 수 있음)

                        // 1. 회전 핸들 (단일 선택 전용)
                        let rotPos = rotationHandleCanvasPos(for: el)
                        if dist(start, rotPos) < handleTolerance {
                            let center = CGPoint(x: el.frame.midX, y: el.frame.midY)
                            let angle = atan2(start.y - center.y,
                                              start.x - center.x) * 180 / .pi
                            vm.beginTransform()
                            vm.activeTransform = .rotating(
                                startMouseAngle: angle,
                                startElementRotation: el.rotation,
                                center: center)
                            NSCursor.crosshair.set()
                            return
                        }
                        // 2. 리사이즈 (단일 선택 전용)
                        if let handle = edgeResizeHandle(at: start, for: el) {
                            vm.beginTransform()
                            let anchor = handle.opposite.canvasPosition(
                                frame: el.frame, rotation: el.rotation)
                            vm.activeTransform = .resizing(
                                handle: handle,
                                startFrame: el.frame,
                                startPoint: start,
                                startRotation: el.rotation,
                                anchorCanvas: anchor)
                            resizeCursor(for: handle, rotation: el.rotation).set()
                            return
                        }
                    }

                    // 3. 선택 모드에서 선택된 요소 위 드래그 → 그룹 이동
                    if vm.selectedTool == .select && !vm.selectedElementIds.isEmpty {
                        let hitSelected = vm.elements.first {
                            vm.selectedElementIds.contains($0.id) && $0.containsPoint(start)
                        }
                        if hitSelected != nil {
                            vm.justCreatedElementId = nil
                            vm.beginTransform()
                            if vm.selectedElementIds.count == 1, let el = vm.selectedElement {
                                vm.activeTransform = .moving(startFrame: el.frame, startPoint: start)
                            } else {
                                let frames = Dictionary(
                                    uniqueKeysWithValues: vm.elements
                                        .filter { vm.selectedElementIds.contains($0.id) }
                                        .map { ($0.id, $0.frame) })
                                vm.activeTransform = .movingGroup(startFrames: frames, startPoint: start)
                            }
                            NSCursor.closedHand.set()
                            return
                        }
                    }

                    // 4. 그리기 도구에서 방금 생성한 요소 이동
                    if let el = vm.selectedElement {
                        let isJustCreated = el.id == vm.justCreatedElementId
                        if isJustCreated && el.containsPoint(start) {
                            vm.justCreatedElementId = nil
                            vm.beginTransform()
                            vm.activeTransform = .moving(startFrame: el.frame, startPoint: start)
                            NSCursor.closedHand.set()
                            return
                        }
                    }

                    // 5. 선택 모드 + 빈 영역 → 마키 선택 시작
                    if vm.selectedTool == .select {
                        vm.selectedElementIds = []
                        marqueeRect = CGRect(origin: start, size: .zero)
                        return
                    }

                    // 6. 그리기 도구
                    vm.handleDragChanged(at: pt)
                    return
                }

                // ── Continue pan phase ───────────────────────────────────────
                if isPanning {
                    vm.canvasOffset = CGSize(
                        width: panStartOffset.width + value.translation.width,
                        height: panStartOffset.height + value.translation.height)
                    return
                }

                // ── Continue marquee phase ───────────────────────────────────
                if marqueeRect != nil {
                    let origin = canvasCoord(from: value.startLocation)
                    marqueeRect = CGRect(
                        x: min(origin.x, pt.x),
                        y: min(origin.y, pt.y),
                        width: abs(pt.x - origin.x),
                        height: abs(pt.y - origin.y))
                    return
                }

                // ── Continue transform phase ─────────────────────────────────
                if let transform = vm.activeTransform {
                    switch transform {
                    case .moving(let startFrame, let startPoint):
                        guard let el = vm.selectedElement else { return }
                        vm.setElementFrame(id: el.id, frame: CGRect(
                            x: startFrame.minX + (pt.x - startPoint.x),
                            y: startFrame.minY + (pt.y - startPoint.y),
                            width: startFrame.width,
                            height: startFrame.height))

                    case .movingGroup(let startFrames, let startPoint):
                        let dx = pt.x - startPoint.x
                        let dy = pt.y - startPoint.y
                        let updated = startFrames.mapValues { f in
                            CGRect(x: f.minX + dx, y: f.minY + dy,
                                   width: f.width, height: f.height)
                        }
                        vm.setElementsFrames(updated)

                    case .resizing(let handle, let startFrame, let startPoint, let startRotation, let anchorCanvas):
                        guard let el = vm.selectedElement else { return }
                        let rawDelta = CGPoint(x: pt.x - startPoint.x, y: pt.y - startPoint.y)
                        let localDelta = rotateVec(rawDelta, by: -startRotation)
                        let proposed = handle.apply(delta: localDelta, to: startFrame)
                        let oppLocal = CGPoint(
                            x: handle.opposite.unitOffset.x * proposed.width,
                            y: handle.opposite.unitOffset.y * proposed.height)
                        let rotOpp = rotateVec(oppLocal, by: startRotation)
                        let currentAnchor = CGPoint(x: proposed.midX + rotOpp.x,
                                                    y: proposed.midY + rotOpp.y)
                        let corrected = CGRect(
                            x: proposed.minX + (anchorCanvas.x - currentAnchor.x),
                            y: proposed.minY + (anchorCanvas.y - currentAnchor.y),
                            width: proposed.width, height: proposed.height)
                        vm.setElementFrame(id: el.id, frame: corrected)

                    case .rotating(let lastAngle, _, let center):
                        guard let el = vm.selectedElement else { return }
                        let currentAngle = atan2(pt.y - center.y,
                                                 pt.x - center.x) * 180 / .pi
                        var delta = currentAngle - lastAngle
                        if delta > 180 { delta -= 360 }
                        if delta < -180 { delta += 360 }
                        let newRotation = el.rotation + delta
                        vm.setElementRotation(id: el.id, rotation: newRotation)
                        vm.activeTransform = .rotating(startMouseAngle: currentAngle,
                                                       startElementRotation: newRotation,
                                                       center: center)
                    }
                    return
                }

                vm.handleDragChanged(at: pt)
            }
            .onEnded { value in
                let endPt = canvasCoord(from: value.location)

                if isPanning {
                    isPanning = false
                    cursorFor(endPt).set()
                    return
                }

                // 마키 선택 완료
                if let mq = marqueeRect {
                    if mq.width > 2 && mq.height > 2 {
                        vm.applyMarqueeSelection(in: mq)
                    }
                    marqueeRect = nil
                    cursorFor(endPt).set()
                    return
                }

                if vm.activeTransform != nil {
                    vm.activeTransform = nil
                    cursorFor(endPt).set()
                    return
                }

                let isTap = abs(value.translation.width) < 4
                    && abs(value.translation.height) < 4
                if isTap { vm.handleTap(at: endPt) }
                else { vm.handleDragEnded(at: endPt) }
                cursorFor(endPt).set()
            }
    }
}

// MARK: - Coordinate helpers

extension DesignCanvasView {
    private func canvasCoord(from v: CGPoint) -> CGPoint {
        // v는 ZStack(뷰포트) 좌표계 기준 — .position() 뒤에 gesture/hover가 있으므로
        // 캔버스 좌상단의 뷰포트 좌표 = 캔버스 중심 - 캔버스 크기의 절반
        let originX = viewportSize.width  / 2 + vm.canvasOffset.width  - vm.project.canvasSize.width  * vm.zoom / 2
        let originY = viewportSize.height / 2 + vm.canvasOffset.height - vm.project.canvasSize.height * vm.zoom / 2
        return CGPoint(x: (v.x - originX) / vm.zoom, y: (v.y - originY) / vm.zoom)
    }

    private func scaled(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        CGRect(x: rect.minX * factor, y: rect.minY * factor,
               width: rect.width * factor, height: rect.height * factor)
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    private func shapePath(type: ShapeElement.ShapeType, in rect: CGRect, cornerRadius r: CGFloat) -> Path {
        switch type {
        case .rectangle: return r > 0 ? Path(roundedRect: rect, cornerRadius: r) : Path(rect)
        case .ellipse: return Path(ellipseIn: rect)
        }
    }

    private func polyline(from points: [CGPoint], zoom z: CGFloat) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * z, y: first.y * z))
        for pt in points.dropFirst() { p.addLine(to: CGPoint(x: pt.x * z, y: pt.y * z)) }
        return p
    }

    private func applyRotation(to ctx: inout GraphicsContext,
                               center: CGPoint, degrees: Double)
    {
        guard degrees != 0 else { return }
        let rad = CGFloat(degrees * .pi / 180)
        ctx.concatenate(
            CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rad)
                .translatedBy(x: -center.x, y: -center.y)
        )
    }
}

// MARK: - Hit-test helpers

extension DesignCanvasView {
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func rotateVec(_ v: CGPoint, by degrees: Double) -> CGPoint {
        let r = CGFloat(degrees * .pi / 180)
        return CGPoint(x: v.x * cos(r) - v.y * sin(r),
                       y: v.x * sin(r) + v.y * cos(r))
    }

    private func rotationHandleCanvasPos(for element: CanvasElement) -> CGPoint {
        let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
        let local = CGPoint(x: element.frame.width / 2 + rotHandleOffset,
                            y: element.frame.height / 2 + rotHandleOffset)
        let rotated = rotateVec(local, by: element.rotation)
        return CGPoint(x: center.x + rotated.x, y: center.y + rotated.y)
    }

    /// 엣지 존 기반 리사이즈 핸들 감지.
    /// 요소의 경계 근처에 있으면 가장 가까운 ResizeHandle을 반환하고,
    /// 내부 중앙 영역이면 nil(이동)을 반환합니다.
    private func edgeResizeHandle(at pt: CGPoint,
                                  for element: CanvasElement) -> ResizeHandle?
    {
        let frame = element.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        // 4 screen px 기준이지만, 요소 최소 변의 25%를 초과하지 않도록 제한.
        // 이렇게 하지 않으면 작은 요소는 center도 edge zone이 되어 resize만 트리거된다.
        let rawEdgeT: CGFloat = 4 / vm.zoom
        let edgeT = min(rawEdgeT, min(frame.width, frame.height) * 0.25)

        // 요소 로컬 좌표로 변환 (회전 역적용)
        let local = rotateVec(
            CGPoint(x: pt.x - center.x, y: pt.y - center.y),
            by: -element.rotation)

        let hw = frame.width / 2
        let hh = frame.height / 2

        // 요소 바운딩 박스 외부면 nil
        guard abs(local.x) <= hw + edgeT,
              abs(local.y) <= hh + edgeT else { return nil }

        let nearLeft = local.x < -hw + edgeT
        let nearRight = local.x > hw - edgeT
        let nearTop = local.y < -hh + edgeT
        let nearBottom = local.y > hh - edgeT

        // 가장자리 내에 없으면 내부 → move 영역
        guard nearLeft || nearRight || nearTop || nearBottom else { return nil }

        // 코너 우선
        if nearLeft, nearTop { return .topLeft }
        if nearRight, nearTop { return .topRight }
        if nearLeft, nearBottom { return .bottomLeft }
        if nearRight, nearBottom { return .bottomRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearTop { return .top }
        return .bottom
    }
}

#Preview {
    DesignCanvasView(vm: IconDesignViewModel())
}
