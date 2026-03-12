import AppKit
import SwiftUI

/// A minimap overlay that shows the entire canvas content and highlights the
/// currently visible viewport area with a red-bordered rectangle.
/// Clicking or dragging on the minimap pans the canvas to that position.
struct MinimapView: View {
    let canvasSize: CGSize
    let zoom: CGFloat
    @Binding var canvasOffset: CGSize
    let viewportSize: CGSize
    let elements: [CanvasElement]
    let backgroundColor: Color

    // Fixed display width; height is derived from canvas aspect ratio.
    private let displayWidth: CGFloat = 160

    private var displayHeight: CGFloat {
        displayWidth * canvasSize.height / canvasSize.width
    }

    /// Scale factor: minimap pixels per canvas pixel
    private var scale: CGFloat {
        displayWidth / canvasSize.width
    }

    /// The visible area of the canvas expressed in canvas coordinates (unclamped).
    private var rawVisibleRect: CGRect {
        CGRect(
            x: canvasSize.width  / 2 - viewportSize.width  / (2 * zoom) - canvasOffset.width  / zoom,
            y: canvasSize.height / 2 - viewportSize.height / (2 * zoom) - canvasOffset.height / zoom,
            width:  viewportSize.width  / zoom,
            height: viewportSize.height / zoom
        )
    }

    /// The visible rect clamped to the canvas bounds, or nil if viewport is fully outside.
    private var clampedVisibleRect: CGRect? {
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let clamped = rawVisibleRect.intersection(canvasBounds)
        return clamped.isNull ? nil : clamped
    }

    /// The clamped visible rect mapped to minimap coordinates.
    private var viewportRectInMinimap: CGRect? {
        guard let r = clampedVisibleRect else { return nil }
        return CGRect(
            x: r.minX * scale,
            y: r.minY * scale,
            width:  r.width  * scale,
            height: r.height * scale
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Canvas background
            Rectangle()
                .fill(Color(nsColor: .underPageBackgroundColor))

            // Canvas content (background color + elements)
            Canvas { ctx, _ in
                ctx.fill(Path(CGRect(origin: .zero,
                                     size: CGSize(width: displayWidth, height: displayHeight))),
                         with: .color(backgroundColor))
                for element in elements where element.isVisible {
                    renderElement(element, in: &ctx, scale: scale)
                }
            }
            .frame(width: displayWidth, height: displayHeight)
            .allowsHitTesting(false)

            // Viewport indicator — only when canvas is at least partially visible
            if let vpRect = viewportRectInMinimap {
                Rectangle()
                    .stroke(Color.red, lineWidth: 1.5)
                    .frame(
                        width:  max(2, vpRect.width),
                        height: max(2, vpRect.height)
                    )
                    .offset(x: vpRect.minX, y: vpRect.minY)
            }
        }
        .frame(width: displayWidth, height: displayHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Convert minimap location to canvas coordinates and
                    // set the offset so the viewport centers on that point.
                    let cx = value.location.x / scale
                    let cy = value.location.y / scale
                    canvasOffset = CGSize(
                        width:  zoom * (canvasSize.width  / 2 - cx),
                        height: zoom * (canvasSize.height / 2 - cy)
                    )
                }
        )
        .onHover { hovering in
            if hovering { NSCursor.openHand.push() }
            else        { NSCursor.pop() }
        }
    }

    // MARK: - Rendering helpers

    private func scaledRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * scale, y: rect.minY * scale,
               width: rect.width * scale, height: rect.height * scale)
    }

    private func shapePath(type: ShapeElement.ShapeType, in rect: CGRect,
                            cornerRadii r: CornerRadii) -> Path {
        switch type {
        case .rectangle:
            if r == .zero { return Path(rect) }
            return UnevenRoundedRectangle(
                topLeadingRadius:     r.topLeft,
                bottomLeadingRadius:  r.bottomLeft,
                bottomTrailingRadius: r.bottomRight,
                topTrailingRadius:    r.topRight
            ).path(in: rect)
        case .ellipse:
            return Path(ellipseIn: rect)
        }
    }

    private func polyline(from points: [CGPoint]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * scale, y: pt.y * scale))
        }
        return p
    }

    private func applyRotation(to ctx: inout GraphicsContext,
                                center: CGPoint, degrees: Double) {
        guard degrees != 0 else { return }
        let rad = CGFloat(degrees * .pi / 180)
        ctx.concatenate(
            CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rad)
                .translatedBy(x: -center.x, y: -center.y)
        )
    }

    private func renderElement(_ element: CanvasElement,
                                in ctx: inout GraphicsContext,
                                scale: CGFloat)
    {
        switch element {
        case .shape(let shape):
            let rect = scaledRect(shape.frame)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let path = shapePath(type: shape.shapeType, in: rect,
                                  cornerRadii: shape.cornerRadii.scaled(by: scale))
            ctx.drawLayer { inner in
                if let sh = shape.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * scale,
                                            x: sh.offsetX * scale,
                                            y: sh.offsetY * scale))
                }
                applyRotation(to: &inner, center: center, degrees: shape.rotation)
                inner.opacity = shape.opacity
                inner.fill(path, with: .color(shape.fillColor))
                if shape.strokeWidth > 0 {
                    inner.stroke(path, with: .color(shape.strokeColor),
                                 lineWidth: max(0.5, shape.strokeWidth * scale))
                }
            }

        case .path(let pathEl):
            guard pathEl.points.count > 1 else { return }
            let f = scaledRect(pathEl.frame)
            let center = CGPoint(x: f.midX, y: f.midY)
            let p = polyline(from: pathEl.points)
            ctx.drawLayer { inner in
                if let sh = pathEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * scale,
                                            x: sh.offsetX * scale,
                                            y: sh.offsetY * scale))
                }
                applyRotation(to: &inner, center: center, degrees: pathEl.rotation)
                inner.opacity = pathEl.opacity
                inner.stroke(p, with: .color(pathEl.color),
                             style: StrokeStyle(lineWidth: max(0.5, pathEl.lineWidth * scale),
                                                lineCap: .round, lineJoin: .round))
            }

        case .image(let imgEl):
            let rect = scaledRect(imgEl.frame)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            guard let cg = imgEl.image.cgImage(forProposedRect: nil,
                                                context: nil, hints: nil) else { return }
            ctx.drawLayer { inner in
                if let sh = imgEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * scale,
                                            x: sh.offsetX * scale,
                                            y: sh.offsetY * scale))
                }
                applyRotation(to: &inner, center: center, degrees: imgEl.rotation)
                inner.opacity = imgEl.opacity
                inner.draw(Image(cg, scale: 1.0, label: Text(imgEl.name)), in: rect)
            }

        case .text(let textEl):
            guard textEl.isVisible, !textEl.text.isEmpty else { return }
            let rect = scaledRect(textEl.frame)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let fontSize = max(1, textEl.fontSize * scale)
            var font = NSFont(name: textEl.fontName, size: fontSize)
                ?? NSFont.systemFont(ofSize: fontSize)
            if textEl.isBold   { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)   }
            if textEl.isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            let ps = NSMutableParagraphStyle()
            ps.alignment = textEl.alignment.nsAlignment
            let attrStr = NSAttributedString(string: textEl.text, attributes: [
                .font: font,
                .foregroundColor: NSColor(textEl.textColor),
                .paragraphStyle: ps,
            ])
            let imgSize = CGSize(width: max(rect.width, 1), height: max(rect.height, 1))
            let ts = NSTextStorage(attributedString: attrStr)
            let lm = NSLayoutManager()
            let tc = NSTextContainer(containerSize: CGSize(
                width: max(rect.width, 1),
                height: CGFloat.greatestFiniteMagnitude))
            ts.addLayoutManager(lm)
            lm.addTextContainer(tc)
            lm.ensureLayout(for: tc)
            let img = NSImage(size: imgSize, flipped: true) { _ in
                lm.drawGlyphs(forGlyphRange: lm.glyphRange(for: tc), at: .zero)
                return true
            }
            ctx.drawLayer { inner in
                if let sh = textEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * scale,
                                            x: sh.offsetX * scale,
                                            y: sh.offsetY * scale))
                }
                applyRotation(to: &inner, center: center, degrees: textEl.rotation)
                inner.opacity = textEl.opacity
                inner.draw(Image(nsImage: img), in: rect)
            }
        }
    }
}

