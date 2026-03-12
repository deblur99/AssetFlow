import AppKit
import SwiftUI

struct DesignCanvasView: View {
    @Bindable var vm: IconDesignViewModel

    // Hit-test tolerance in canvas (model) coordinates
    private var handleTolerance: CGFloat { 8 / vm.zoom }
    private var rotHandleOffset: CGFloat { 24 / vm.zoom }

    @State private var scrollMonitor: Any?
    @State private var magnifyMonitor: Any?
    @State private var isPanning = false
    @State private var panStartOffset: CGSize = .zero
    /// 선택 모드에서 드래그로 그리는 마키 사각형 (캔버스 좌표)
    @State private var marqueeRect: CGRect?
    /// 중앙 정렬 스냅 활성 여부 (X: 수직 가이드, Y: 수평 가이드)
    @State private var snapX = false
    @State private var snapY = false
    private class HoverState { var isHovering = false }
    @State private var hoverState = HoverState()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                
                canvasLayer
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .position(
                        x: geometry.size.width / 2 + vm.canvasOffset.width,
                        y: geometry.size.height / 2 + vm.canvasOffset.height)
                
                // 인라인 텍스트 편집기 오버레이 (편집 모드일 때만 표시)
                textEditorOverlay(viewSize: geometry.size)

                TipBannerView(isPresented: $vm.isTipBannerPresented)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .top
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            // geometry.size를 직접 전달 — @State 타이밍 문제 없이 항상 최신 크기 사용
            .gesture(makeInteractionGesture(viewSize: geometry.size))
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverState.isHovering = true
                    cursorFor(canvasCoord(from: location, viewSize: geometry.size)).set()
                case .ended:
                    hoverState.isHovering = false
                    NSCursor.arrow.set()
                }
            }
            .contextMenu {
                canvasContextMenu(viewSize: geometry.size)
            }
            .onAppear {
                vm.zoomToFit(in: geometry.size)
                setupScrollWheelZoom()
                setupMagnifyMonitor()
            }
            .onDisappear {
                if let m = scrollMonitor  { NSEvent.removeMonitor(m); scrollMonitor  = nil }
                if let m = magnifyMonitor { NSEvent.removeMonitor(m); magnifyMonitor = nil }
            }
            .onChange(of: geometry.size) { _, s in vm.zoomToFit(in: s) }
            .overlay(alignment: .bottomTrailing) {
                MinimapView(
                    canvasSize: vm.project.canvasSize,
                    zoom: vm.zoom,
                    canvasOffset: $vm.canvasOffset,
                    viewportSize: geometry.size)
                    .padding(12)
            }
        }
        // GeometryReader 자체에 이름을 붙여 항상 이 뷰의 로컬 좌표계를 기준으로 삼음
        .coordinateSpace(.named("viewport"))
    }

    // MARK: - Inline text editor overlay

    @ViewBuilder
    private func textEditorOverlay(viewSize: CGSize) -> some View {
        if let editingId = vm.editingTextElementId,
           let element = vm.project.elements.first(where: { $0.id == editingId }),
           case .text(let textEl) = element
        {
            let screenRect = canvasRectToScreen(textEl.frame, viewSize: viewSize)
            InlineTextEditor(
                text: Binding(
                    get: { textEl.text },
                    set: { vm.updateTextContent(id: editingId, text: $0) }
                ),
                fontName: textEl.fontName,
                fontSize: textEl.fontSize * vm.zoom,
                isBold: textEl.isBold,
                isItalic: textEl.isItalic,
                textColor: textEl.textColor.opacity(textEl.opacity),
                alignment: textEl.alignment,
                onEndEditing: { vm.endTextEdit() },
                onSizeChange: { screenSize in
                    // 화면 크기 → 캔버스 좌표계 크기로 변환
                    let canvasSize = CGSize(
                        width:  screenSize.width  / vm.zoom,
                        height: screenSize.height / vm.zoom)
                    vm.updateTextFrame(id: editingId, canvasSize: canvasSize)
                }
            )
            .background(Color.accentColor.opacity(0.06))
            .overlay(
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .frame(width: max(screenRect.width, 2), height: max(screenRect.height, 4))
            .rotationEffect(.degrees(textEl.rotation))
            .position(x: screenRect.midX, y: screenRect.midY)
            .zIndex(10)
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

            // 중앙 정렬 스냅 가이드라인
            if snapX {
                let x = vm.project.canvasSize.width / 2 * vm.zoom
                Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: vm.project.canvasSize.height * vm.zoom))
                }
                .stroke(Color.cyan.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .allowsHitTesting(false)
            }
            if snapY {
                let y = vm.project.canvasSize.height / 2 * vm.zoom
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: vm.project.canvasSize.width * vm.zoom, y: y))
                }
                .stroke(Color.cyan.opacity(0.85),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
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

        case .text(let textEl):
            guard textEl.isVisible, textEl.id != vm.editingTextElementId else { return }
            guard !textEl.text.isEmpty else { return }
            let rect = scaled(textEl.frame, by: z)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var font = NSFont(name: textEl.fontName, size: textEl.fontSize * z)
                ?? NSFont.systemFont(ofSize: textEl.fontSize * z)
            if textEl.isBold   { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)   }
            if textEl.isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            let ps = NSMutableParagraphStyle()
            ps.alignment = textEl.alignment.nsAlignment
            let attrStr = NSAttributedString(string: textEl.text, attributes: [
                .font: font,
                .foregroundColor: NSColor(textEl.textColor),
                .paragraphStyle: ps,
            ])

            // NSTextView도 내부적으로 NSLayoutManager.drawGlyphs(at: textContainerOrigin)를 사용한다.
            // 동일한 메서드를 직접 호출해 렌더링 엔진을 완전히 일치시킴.
            // → attrStr.draw(at:)와 달리 line-fragment 기준점이 정확히 (0,0)에서 시작됨.
            let ts = NSTextStorage(attributedString: attrStr)
            let lm = NSLayoutManager()
            let tc = NSTextContainer(containerSize: CGSize(
                width:  CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude))
            ts.addLayoutManager(lm)
            lm.addTextContainer(tc)
            lm.ensureLayout(for: tc)

            let imgSize = CGSize(width: max(rect.width, 1), height: max(rect.height, 1))
            // NSImage의 드로잉 핸들러는 디스플레이 스케일에 맞춰 자동 호출됨 (Retina 대응)
            let img = NSImage(size: imgSize, flipped: true) { _ in
                lm.drawGlyphs(forGlyphRange: lm.glyphRange(for: tc), at: .zero)
                return true
            }
            ctx.drawLayer { inner in
                applyRotation(to: &inner, center: center, degrees: textEl.rotation)
                inner.opacity = textEl.opacity
                // Image(nsImage:)는 논리적 크기 기준으로 그려줌 — cgImage 변환 불필요
                inner.draw(Image(nsImage: img), in: rect)
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
        case .pen, .rectangle, .ellipse, .text: return .crosshair
        }    }

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
    /// 핀치 줌 — MagnificationGesture 대신 NSEvent 모니터를 사용해
    /// DragGesture와의 simultaneousGesture 조율 오버헤드(end 지연)를 제거한다.
    private func setupMagnifyMonitor() {
        guard magnifyMonitor == nil else { return }
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [hoverState] event in
            guard hoverState.isHovering else { return event }
            let delta = event.magnification  // +: 확대, -: 축소
            DispatchQueue.main.async {
                let dampened = 1 + delta * 0.6
                self.vm.zoom = max(0.05, min(self.vm.zoom * dampened, 16.0))
            }
            return event
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
                // macOS가 shift+스크롤을 scrollingDeltaX로 변환하는 경우와 그렇지 않은 경우 모두 처리
                let rawDelta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.scrollingDeltaY
                dx = rawDelta
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
    private func makeInteractionGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("viewport"))
            .onChanged { value in
                let pt = canvasCoord(from: value.location, viewSize: viewSize)
                let start = canvasCoord(from: value.startLocation, viewSize: viewSize)

                // ── Begin phase ─────────────────────────────────────────────
                if vm.activeTransform == nil
                    && !isPanning
                    && vm.activePathPoints.isEmpty
                    && vm.activeDragStart == nil
                    && marqueeRect == nil
                {
                    // ── 캔버스 영역 바깥 클릭 → 항상 패닝 ──────────────────────
                    let canvasBounds = CGRect(
                        x: viewSize.width  / 2 + vm.canvasOffset.width  - vm.project.canvasSize.width  * vm.zoom / 2,
                        y: viewSize.height / 2 + vm.canvasOffset.height - vm.project.canvasSize.height * vm.zoom / 2,
                        width:  vm.project.canvasSize.width  * vm.zoom,
                        height: vm.project.canvasSize.height * vm.zoom)
                    if !canvasBounds.contains(value.startLocation) {
                        isPanning = true
                        panStartOffset = vm.canvasOffset
                        NSCursor.closedHand.set()
                        return
                    }
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
                    let origin = canvasCoord(from: value.startLocation, viewSize: viewSize)
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
                        let canvasCenter = CGPoint(
                            x: vm.project.canvasSize.width  / 2,
                            y: vm.project.canvasSize.height / 2)
                        let threshold: CGFloat = 8 / vm.zoom

                        var newX = startFrame.minX + (pt.x - startPoint.x)
                        var newY = startFrame.minY + (pt.y - startPoint.y)

                        // X축 중앙 스냅 (레이어 midX ≈ 캔버스 수직 중심선)
                        let proposedMidX = newX + startFrame.width  / 2
                        let newSnapX = abs(proposedMidX - canvasCenter.x) < threshold
                        if newSnapX { newX = canvasCenter.x - startFrame.width  / 2 }
                        if newSnapX && !snapX { triggerAlignmentHaptic() }
                        snapX = newSnapX

                        // Y축 중앙 스냅 (레이어 midY ≈ 캔버스 수평 중심선)
                        let proposedMidY = newY + startFrame.height / 2
                        let newSnapY = abs(proposedMidY - canvasCenter.y) < threshold
                        if newSnapY { newY = canvasCenter.y - startFrame.height / 2 }
                        if newSnapY && !snapY { triggerAlignmentHaptic() }
                        snapY = newSnapY

                        vm.setElementFrame(id: el.id, frame: CGRect(
                            x: newX, y: newY,
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
                let endPt = canvasCoord(from: value.location, viewSize: viewSize)

                if isPanning {
                    isPanning = false
                    cursorFor(endPt).set()
                    return
                }

                // 마키 선택 완료
                if let mq = marqueeRect {
                    marqueeRect = nil
                    if mq.width > 2 && mq.height > 2 {
                        // 실제 드래그 → 마키 선택
                        vm.applyMarqueeSelection(in: mq)
                    } else {
                        // 탭으로 끝난 마키(거의 이동 없음) → 일반 탭 처리
                        vm.handleTap(at: endPt)
                    }
                    cursorFor(endPt).set()
                    return
                }

                if vm.activeTransform != nil {
                    vm.activeTransform = nil
                    snapX = false
                    snapY = false
                    cursorFor(endPt).set()
                    return
                }

                // 펜 도구 활성 경로: translation 크기와 무관하게 항상 finalize
                // (짧은 획도 isTap으로 오판되어 activePathPoints가 잔존하는 버그 방지)
                if !vm.activePathPoints.isEmpty {
                    vm.handleDragEnded(at: endPt)
                    cursorFor(endPt).set()
                    return
                }

                let isTap = abs(value.translation.width) < 4
                    && abs(value.translation.height) < 4
                if isTap {
                    if vm.selectedTool == .text {
                        if let editingId = vm.editingTextElementId {
                            // 편집 중: 현재 편집 중인 요소를 클릭 → 계속 편집
                            //          그 외 어디를 클릭해도 → 편집 종료
                            let editingEl = vm.project.elements.first { $0.id == editingId }
                            let isSameElement = editingEl.map { $0.containsPoint(endPt) } ?? false
                            if !isSameElement {
                                vm.endTextEdit()
                            }
                        } else {
                            // 편집 중 아님: 텍스트 요소 클릭 → 편집 시작, 빈 공간 클릭 → 새 생성
                            let hit = vm.project.elements.reversed().first { $0.isVisible && $0.containsPoint(endPt) }
                            if let hit, case .text(let t) = hit {
                                vm.selectedElementIds = [t.id]
                                vm.beginTextEdit(id: t.id)
                            } else {
                                vm.createTextElement(at: endPt)
                            }
                        }
                    } else {
                        // 다른 도구 탭: 텍스트 편집 중이면 종료
                        if vm.editingTextElementId != nil { vm.endTextEdit() }
                        vm.handleTap(at: endPt)
                    }
                } else {
                    vm.handleDragEnded(at: endPt)
                }
                cursorFor(endPt).set()
            }
    }
}

// MARK: - Context menu

extension DesignCanvasView {
    @ViewBuilder
    private func canvasContextMenu(viewSize: CGSize) -> some View {
        let hasSelection = !vm.selectedElementIds.isEmpty
        let id = vm.selectedElement?.id
        
        Button {
            vm.cutSelectedElement()
        } label: {
            Label("Cut", systemImage: "scissors")
        }
        .keyboardShortcut("x", modifiers: .command)
        .disabled(!hasSelection)
        
        Button {
            vm.copySelectedElement()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: .command)
        .disabled(!hasSelection)

        Button {
            vm.pasteElement()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("v", modifiers: .command)
        .disabled(vm.clipboard == nil)

        if let id {
            Divider()

            Button {
                vm.bringForward(id: id)
            } label: {
                Label("Bring Forward", systemImage: "square.2.layers.3d.top.filled")
            }
            .keyboardShortcut("]", modifiers: .command)

            Button {
                vm.sendBackward(id: id)
            } label: {
                Label("Send Backward", systemImage: "square.2.layers.3d.bottom.filled")
            }
            .keyboardShortcut("[", modifiers: .command)

            Button {
                vm.bringToFront(id: id)
            } label: {
                Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button {
                vm.sendToBack(id: id)
            } label: {
                Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
        }
    }
}

// MARK: - Coordinate helpers

extension DesignCanvasView {
    private func canvasCoord(from v: CGPoint, viewSize: CGSize) -> CGPoint {
        // v는 named "viewport" 좌표계(GeometryReader 기준) — canvasOffset 변화에도 원점 불변
        let originX = viewSize.width  / 2 + vm.canvasOffset.width  - vm.project.canvasSize.width  * vm.zoom / 2
        let originY = viewSize.height / 2 + vm.canvasOffset.height - vm.project.canvasSize.height * vm.zoom / 2
        return CGPoint(x: (v.x - originX) / vm.zoom, y: (v.y - originY) / vm.zoom)
    }

    /// 캔버스 좌표계의 rect를 뷰포트(GeometryReader) 좌표계로 변환한다.
    private func canvasRectToScreen(_ rect: CGRect, viewSize: CGSize) -> CGRect {
        let originX = viewSize.width  / 2 + vm.canvasOffset.width  - vm.project.canvasSize.width  * vm.zoom / 2
        let originY = viewSize.height / 2 + vm.canvasOffset.height - vm.project.canvasSize.height * vm.zoom / 2
        return CGRect(
            x:      originX + rect.minX * vm.zoom,
            y:      originY + rect.minY * vm.zoom,
            width:  rect.width  * vm.zoom,
            height: rect.height * vm.zoom)
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

    /// 트랙패드 정렬 햅틱 — 레이어가 캔버스 중앙에 스냅될 때 호출
    private func triggerAlignmentHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .drawCompleted)
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
