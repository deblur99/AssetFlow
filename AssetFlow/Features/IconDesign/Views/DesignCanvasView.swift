import SwiftUI

struct DesignCanvasView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                canvasLayer
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .gesture(drawingGesture)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                vm.zoomToFit(in: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                vm.zoomToFit(in: newSize)
            }
        }
    }

    // MARK: - Canvas

    private var canvasLayer: some View {
        ZStack(alignment: .topLeading) {
            vm.project.backgroundColor

            // Render all committed elements + active preview
            Canvas { ctx, _ in
                let z = vm.zoom

                for element in vm.elements {
                    guard element.isVisible else { continue }
                    renderElement(element, in: &ctx, zoom: z)
                }

                renderActivePreview(in: &ctx, zoom: z)
            }

            // Selection outline (uses SwiftUI layer for crisp dashes)
            if let element = vm.selectedElement {
                selectionOverlay(for: element)
            }
        }
        .frame(
            width:  vm.project.canvasSize.width  * vm.zoom,
            height: vm.project.canvasSize.height * vm.zoom
        )
    }

    // MARK: - Element rendering (Canvas)

    private func renderElement(_ element: CanvasElement, in ctx: inout GraphicsContext, zoom z: CGFloat) {
        switch element {
        case .shape(let shape):
            let rect = scaled(shape.frame, by: z)
            let path = shapePath(type: shape.shapeType, in: rect, cornerRadius: shape.cornerRadius * z)
            ctx.drawLayer { inner in
                inner.opacity = shape.opacity
                inner.fill(path, with: .color(shape.fillColor))
                if shape.strokeWidth > 0 {
                    inner.stroke(path, with: .color(shape.strokeColor),
                                 lineWidth: shape.strokeWidth * z)
                }
            }

        case .path(let pathEl):
            guard pathEl.points.count > 1 else { return }
            let p = polyline(from: pathEl.points, zoom: z)
            ctx.drawLayer { inner in
                inner.opacity = pathEl.opacity
                inner.stroke(p, with: .color(pathEl.color),
                             style: StrokeStyle(lineWidth: pathEl.lineWidth * z,
                                               lineCap: .round, lineJoin: .round))
            }

        case .image(let imgEl):
            let rect = scaled(imgEl.frame, by: z)
            if let cg = imgEl.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                ctx.drawLayer { inner in
                    inner.opacity = imgEl.opacity
                    inner.draw(Image(cg, scale: 1.0, label: Text(imgEl.name)), in: rect)
                }
            }
        }
    }

    private func renderActivePreview(in ctx: inout GraphicsContext, zoom z: CGFloat) {
        // Freehand pen preview
        if vm.activePathPoints.count > 1 {
            let p = polyline(from: vm.activePathPoints, zoom: z)
            let color = vm.strokeColor == .clear ? vm.fillColor : vm.strokeColor
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: vm.lineWidth * z,
                                         lineCap: .round, lineJoin: .round))
        }

        // Shape drag preview
        if let start = vm.activeDragStart, let end = vm.activeDragCurrent {
            let rect = scaled(normalizedRect(from: start, to: end), by: z)
            let type: ShapeElement.ShapeType = vm.selectedTool == .rectangle ? .rectangle : .ellipse
            let path = shapePath(type: type, in: rect, cornerRadius: vm.cornerRadius * z)
            ctx.fill(path, with: .color(vm.fillColor.opacity(0.6)))
            let previewStroke = vm.strokeColor == .clear
                ? Color.gray.opacity(0.6)
                : vm.strokeColor
            ctx.stroke(path, with: .color(previewStroke), lineWidth: max(1, vm.lineWidth * z))
        }
    }

    // MARK: - Selection overlay

    @ViewBuilder
    private func selectionOverlay(for element: CanvasElement) -> some View {
        let z = vm.zoom
        let f = element.frame
        Rectangle()
            .stroke(Color.accentColor,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
            .frame(width: max(f.width * z, 2), height: max(f.height * z, 2))
            .position(x: f.midX * z, y: f.midY * z)
    }

    // MARK: - Gesture

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let pt = canvasCoord(from: value.location)
                vm.handleDragChanged(at: pt)
            }
            .onEnded { value in
                let pt = canvasCoord(from: value.location)
                let isTap = abs(value.translation.width)  < 4
                         && abs(value.translation.height) < 4
                if isTap {
                    vm.handleTap(at: pt)
                } else {
                    vm.handleDragEnded(at: pt)
                }
            }
    }

    // MARK: - Coordinate helpers

    /// Convert a point in the scaled canvas view to canvas (model) coordinates.
    private func canvasCoord(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewPoint.x / vm.zoom, y: viewPoint.y / vm.zoom)
    }

    private func scaled(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        CGRect(x: rect.minX * factor, y: rect.minY * factor,
               width: rect.width * factor, height: rect.height * factor)
    }

    private func shapePath(type: ShapeElement.ShapeType, in rect: CGRect, cornerRadius r: CGFloat) -> Path {
        switch type {
        case .rectangle: return r > 0 ? Path(roundedRect: rect, cornerRadius: r) : Path(rect)
        case .ellipse:   return Path(ellipseIn: rect)
        }
    }

    private func polyline(from points: [CGPoint], zoom z: CGFloat) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * z, y: first.y * z))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * z, y: pt.y * z))
        }
        return p
    }

    private func normalizedRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
