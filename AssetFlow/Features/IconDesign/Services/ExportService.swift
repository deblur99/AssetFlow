import AppKit
import SwiftUI

// MARK: - Canvas export view (used by ImageRenderer for raster/PDF)

struct CanvasExportView: View {
    let elements: [CanvasElement]
    let canvasSize: CGSize
    let targetSize: CGSize

    private var scale: CGFloat {
        min(targetSize.width / canvasSize.width,
            targetSize.height / canvasSize.height)
    }

    private var offset: CGPoint {
        CGPoint(
            x: (targetSize.width - canvasSize.width * scale) / 2,
            y: (targetSize.height - canvasSize.height * scale) / 2
        )
    }

    /// Background solid fill used for letterbox area (if any).
    private var letterboxColor: Color {
        for e in elements {
            if case .background(let bg) = e { return bg.fillColor }
        }
        return .white
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(letterboxColor))
            for element in elements where element.isVisible {
                renderElement(element, in: &ctx, zoom: scale, offset: offset)
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
    }

    // MARK: - Render helpers

    private func renderElement(_ element: CanvasElement,
                               in ctx: inout GraphicsContext,
                               zoom z: CGFloat, offset o: CGPoint)
    {
        switch element {
        case .shape(let shape):
            let rect = scaled(shape.frame, by: z, offset: o)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let path = shapePath(type: shape.shapeType, in: rect,
                                 cornerRadii: shape.cornerRadii.scaled(by: z))
            ctx.drawLayer { inner in
                if let sh = shape.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * z,
                                            x: sh.offsetX * z, y: sh.offsetY * z))
                }
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
            let f2 = scaled(pathEl.frame, by: z, offset: o)
            let center = CGPoint(x: f2.midX, y: f2.midY)
            let p = polyline(from: pathEl.points, zoom: z, offset: o)
            ctx.drawLayer { inner in
                if let sh = pathEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * z,
                                            x: sh.offsetX * z, y: sh.offsetY * z))
                }
                applyRotation(to: &inner, center: center, degrees: pathEl.rotation)
                inner.opacity = pathEl.opacity
                inner.stroke(p, with: .color(pathEl.color),
                             style: StrokeStyle(lineWidth: pathEl.lineWidth * z,
                                                lineCap: .round, lineJoin: .round))
            }

        case .image(let imgEl):
            let rect = scaled(imgEl.frame, by: z, offset: o)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            guard let cg = imgEl.image.cgImage(forProposedRect: nil,
                                               context: nil, hints: nil) else { return }
            ctx.drawLayer { inner in
                if let sh = imgEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * z,
                                            x: sh.offsetX * z, y: sh.offsetY * z))
                }
                applyRotation(to: &inner, center: center, degrees: imgEl.rotation)
                inner.opacity = imgEl.opacity
                inner.draw(Image(cg, scale: 1.0, label: Text(imgEl.name)), in: rect)
            }

        case .text(let textEl):
            guard textEl.isVisible, !textEl.text.isEmpty else { return }
            let rect = scaled(textEl.frame, by: z, offset: o)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            var font = NSFont(name: textEl.fontName, size: textEl.fontSize * z)
                ?? NSFont.systemFont(ofSize: textEl.fontSize * z)
            if textEl.isBold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if textEl.isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            let ps = NSMutableParagraphStyle()
            let attrStr = NSAttributedString(string: textEl.text, attributes: [
                .font: font,
                .foregroundColor: NSColor(textEl.textColor),
                .paragraphStyle: ps,
            ])
            let ts = NSTextStorage(attributedString: attrStr)
            let lm = NSLayoutManager()
            let tc = NSTextContainer(containerSize: CGSize(
                width: max(rect.width, 1),
                height: CGFloat.greatestFiniteMagnitude
            ))
            ts.addLayoutManager(lm)
            lm.addTextContainer(tc)
            lm.ensureLayout(for: tc)
            let imgSize = CGSize(width: max(rect.width, 1), height: max(rect.height, 1))
            let img = NSImage(size: imgSize, flipped: true) { _ in
                lm.drawGlyphs(forGlyphRange: lm.glyphRange(for: tc), at: .zero)
                return true
            }
            ctx.drawLayer { inner in
                if let sh = textEl.shadow {
                    inner.addFilter(.shadow(color: sh.color,
                                            radius: sh.blur * z,
                                            x: sh.offsetX * z, y: sh.offsetY * z))
                }
                applyRotation(to: &inner, center: center, degrees: textEl.rotation)
                inner.opacity = textEl.opacity
                inner.draw(Image(nsImage: img), in: rect)
            }

        case .background(let bg):
            let rect = CGRect(x: o.x, y: o.y,
                              width: canvasSize.width * z, height: canvasSize.height * z)
            ctx.drawLayer { inner in
                inner.opacity = bg.opacity
                if let grad = bg.gradient {
                    let sorted = grad.stops.sorted { $0.location < $1.location }
                    let gradient = Gradient(stops: sorted.map {
                        Gradient.Stop(color: $0.color, location: $0.location)
                    })
                    switch grad.type {
                    case .linear:
                        let r = CGFloat(grad.angle * .pi / 180)
                        let start = CGPoint(x: rect.midX - sin(r) * rect.width * 0.5,
                                            y: rect.midY - cos(r) * rect.height * 0.5)
                        let end = CGPoint(x: rect.midX + sin(r) * rect.width * 0.5,
                                          y: rect.midY + cos(r) * rect.height * 0.5)
                        inner.fill(Path(rect), with: .linearGradient(gradient,
                                                                     startPoint: start,
                                                                     endPoint: end))
                    case .radial:
                        let radius = hypot(rect.width, rect.height) * 0.5
                        inner.fill(Path(rect), with: .radialGradient(gradient,
                                                                     center: CGPoint(x: rect.midX, y: rect.midY),
                                                                     startRadius: 0,
                                                                     endRadius: radius))
                    case .angular:
                        inner.fill(Path(rect), with: .conicGradient(gradient,
                                                                    center: CGPoint(x: rect.midX, y: rect.midY)))
                    }
                } else {
                    inner.fill(Path(rect), with: .color(bg.fillColor))
                }
            }
        }
    }

    private func scaled(_ rect: CGRect, by factor: CGFloat, offset: CGPoint) -> CGRect {
        CGRect(x: rect.minX * factor + offset.x,
               y: rect.minY * factor + offset.y,
               width: rect.width * factor,
               height: rect.height * factor)
    }

    private func polyline(from points: [CGPoint], zoom z: CGFloat, offset: CGPoint) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * z + offset.x, y: first.y * z + offset.y))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * z + offset.x, y: pt.y * z + offset.y))
        }
        return p
    }

    private func shapePath(type: ShapeElement.ShapeType,
                           in rect: CGRect, cornerRadii r: CornerRadii) -> Path
    {
        switch type {
        case .rectangle:
            if r == .zero { return Path(rect) }
            return UnevenRoundedRectangle(
                topLeadingRadius: r.topLeft,
                bottomLeadingRadius: r.bottomLeft,
                bottomTrailingRadius: r.bottomRight,
                topTrailingRadius: r.topRight
            ).path(in: rect)
        case .ellipse:
            return Path(ellipseIn: rect)
        }
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

// MARK: - Export service

@MainActor
enum ExportService {
    static func export(vm: IconDesignViewModel) {
        performExport(
            elements: vm.project.elements,
            canvasSize: vm.project.canvasSize,
            targetSize: vm.exportSize.size,
            format: vm.exportFormat,
            fileName: vm.project.name
        )
    }

    /// 선택한 레이어들만 내보내기. 배경 레이어는 렌더링용으로 항상 포함된다.
    static func exportLayers(_ layers: [CanvasElement], vm: IconDesignViewModel) {
        let background = vm.project.elements.first { if case .background = $0 { return true }; return false }
        var elementsToRender = layers
        if let bg = background, !elementsToRender.contains(where: { $0.id == bg.id }) {
            elementsToRender.insert(bg, at: 0)
        }
        let fileName = layers.count == 1 ? layers[0].name : vm.project.name
        performExport(
            elements: elementsToRender,
            canvasSize: vm.project.canvasSize,
            targetSize: vm.exportSize.size,
            format: vm.exportFormat,
            fileName: fileName
        )
    }

    // DispatchQueue.main.async guarantees NSThread.isMainThread == true,
    // which AppKit requires for NSSavePanel. @MainActor alone does not
    // satisfy AppKit's pthread-based thread check in all SwiftUI contexts.
    // - Signing & Capabilities - App Sandbox - File Access - User Selected File에서 권한을 Read Only에서 Read/Write로 수정하여 앱 크래시 방지
    private static func performExport(
        elements: [CanvasElement],
        canvasSize: CGSize,
        targetSize: CGSize,
        format: ExportFormat,
        fileName: String
    ) {
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.allowedContentTypes = [format.utType]
            panel.nameFieldStringValue = fileName

            let response = await panel.begin()
            guard response == .OK, let url = panel.url else { return }

            var saveError: Error?
            if format == .svg {
                let svg = SVGGenerator.generate(elements: elements,
                                                canvasSize: canvasSize,
                                                targetSize: targetSize)
                do {
                    try svg.data(using: .utf8)?.write(to: url)
                } catch {
                    saveError = error
                }
            } else {
                let exportView = CanvasExportView(elements: elements,
                                                  canvasSize: canvasSize,
                                                  targetSize: targetSize)
                let renderer = ImageRenderer(content: exportView)
                renderer.scale = 1.0
                guard let nsImage = renderer.nsImage else { return }

                let data: Data?
                switch format {
                case .png: data = nsImage.exportPNGData()
                case .jpeg: data = nsImage.exportJPEGData()
                case .pdf: data = makePDFData(from: nsImage, size: targetSize)
                case .svg: data = nil
                }
                do {
                    try data?.write(to: url)
                } catch {
                    saveError = error
                }
            }

            showSaveResult(url: url, error: saveError)
        }
    }

    @MainActor
    private static func showSaveResult(url: URL, error: Error?) {
        let alert = NSAlert()
        if let error {
            alert.alertStyle = .critical
            alert.messageText = "저장 실패"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "확인")
            alert.runModal()
        } else {
            alert.alertStyle = .informational
            alert.messageText = "저장 완료"
            alert.informativeText = url.path
            alert.addButton(withTitle: "Finder에서 열기")
            alert.addButton(withTitle: "확인")
            let result = alert.runModal()
            if result == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private static func makePDFData(from image: NSImage, size: CGSize) -> Data? {
        var box = CGRect(origin: .zero, size: size)
        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        ctx.beginPDFPage(nil)
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            ctx.draw(cg, in: box)
        }
        ctx.endPDFPage()
        ctx.closePDF()
        return mutableData as Data
    }
}

// MARK: - NSImage export helpers

private extension NSImage {
    func exportPNGData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    func exportJPEGData(compressionQuality: CGFloat = 0.92) -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg,
                                  properties: [.compressionFactor: compressionQuality])
    }
}

// MARK: - SVG Generator

enum SVGGenerator {
    static func generate(elements: [CanvasElement],
                         canvasSize: CGSize,
                         targetSize: CGSize) -> String
    {
        let uniformScale = min(targetSize.width / canvasSize.width,
                               targetSize.height / canvasSize.height)
        let offsetX = (targetSize.width - canvasSize.width * uniformScale) / 2
        let offsetY = (targetSize.height - canvasSize.height * uniformScale) / 2

        var defs = [String]()
        var shapes = [String]()
        var idx = 0

        // Letterbox fill
        let lbColor = elements.compactMap { e -> Color? in
            guard case .background(let bg) = e else { return nil }
            return bg.fillColor
        }.first ?? .white
        shapes.append(
            "<rect width=\"\(fi(targetSize.width))\" height=\"\(fi(targetSize.height))\" fill=\"\(lbColor.svgHex)\"/>"
        )

        for element in elements where element.isVisible {
            switch element {
            case .background(let bg):
                let x = offsetX, y = offsetY
                let w = canvasSize.width * uniformScale, h = canvasSize.height * uniformScale
                if let grad = bg.gradient {
                    let gid = "grad_\(idx)"; idx += 1
                    defs.append(svgGradient(id: gid, config: grad, x: x, y: y, w: w, h: h))
                    shapes.append(
                        "<rect x=\"\(f(x))\" y=\"\(f(y))\" width=\"\(f(w))\" height=\"\(f(h))\" fill=\"url(#\(gid))\" opacity=\"\(f(bg.opacity))\"/>"
                    )
                } else {
                    shapes.append(
                        "<rect x=\"\(f(x))\" y=\"\(f(y))\" width=\"\(f(w))\" height=\"\(f(h))\" fill=\"\(bg.fillColor.svgHex)\" opacity=\"\(f(bg.opacity))\"/>"
                    )
                }

            case .shape(let s):
                let fr = frame(s.frame, scale: uniformScale, ox: offsetX, oy: offsetY)
                let transform = rotateAttr(s.rotation, cx: fr.midX, cy: fr.midY)
                var shadAttr = ""
                if let sh = s.shadow {
                    let fid = "shf_\(idx)"; idx += 1
                    defs.append(svgDropShadow(id: fid, shadow: sh, scale: uniformScale))
                    shadAttr = " filter=\"url(#\(fid))\""
                }
                let fill = s.fillColor.svgFill
                let stroke = s.strokeColor.svgFill
                let sw = s.strokeWidth * uniformScale
                switch s.shapeType {
                case .rectangle:
                    shapes.append(roundedRectSVG(fr, radii: s.cornerRadii.scaled(by: uniformScale),
                                                 fill: fill, stroke: stroke, sw: sw,
                                                 opacity: s.opacity,
                                                 extra: transform + shadAttr))
                case .ellipse:
                    shapes.append(
                        "<ellipse cx=\"\(f(fr.midX))\" cy=\"\(f(fr.midY))\" rx=\"\(f(fr.width / 2))\" ry=\"\(f(fr.height / 2))\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(f(sw))\" opacity=\"\(f(s.opacity))\"\(transform)\(shadAttr)/>"
                    )
                }

            case .path(let pe):
                guard pe.points.count > 1 else { continue }
                var shadAttr = ""
                if let sh = pe.shadow {
                    let fid = "shf_\(idx)"; idx += 1
                    defs.append(svgDropShadow(id: fid, shadow: sh, scale: uniformScale))
                    shadAttr = " filter=\"url(#\(fid))\""
                }
                let pts = pe.points.map { CGPoint(x: $0.x * uniformScale + offsetX,
                                                  y: $0.y * uniformScale + offsetY) }
                let d = "M " + pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " L ")
                let fr = frame(pe.frame, scale: uniformScale, ox: offsetX, oy: offsetY)
                let transform = rotateAttr(pe.rotation, cx: fr.midX, cy: fr.midY)
                let col = pe.color.isTransparentColor ? "#000000" : pe.color.svgHex
                shapes.append(
                    "<path d=\"\(d)\" fill=\"none\" stroke=\"\(col)\" stroke-width=\"\(f(pe.lineWidth * uniformScale))\" stroke-linecap=\"round\" stroke-linejoin=\"round\" opacity=\"\(f(pe.opacity))\"\(transform)\(shadAttr)/>"
                )

            case .image(let ie):
                let fr = frame(ie.frame, scale: uniformScale, ox: offsetX, oy: offsetY)
                let transform = rotateAttr(ie.rotation, cx: fr.midX, cy: fr.midY)
                guard let tiff = ie.image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { continue }
                let b64 = png.base64EncodedString()
                shapes.append(
                    "<image href=\"data:image/png;base64,\(b64)\" x=\"\(f(fr.minX))\" y=\"\(f(fr.minY))\" width=\"\(f(fr.width))\" height=\"\(f(fr.height))\" opacity=\"\(f(ie.opacity))\"\(transform)/>"
                )

            case .text(let te):
                let fr = frame(te.frame, scale: uniformScale, ox: offsetX, oy: offsetY)
                let transform = rotateAttr(te.rotation, cx: fr.midX, cy: fr.midY)
                let fs = te.fontSize * uniformScale
                let fw = te.isBold ? "bold" : "normal"
                let fst = te.isItalic ? "italic" : "normal"
                let (anchor, tx): (String, Double) = ("start", Double(fr.minX))
                var shadAttr = ""
                if let sh = te.shadow {
                    let fid = "shf_\(idx)"; idx += 1
                    defs.append(svgDropShadow(id: fid, shadow: sh, scale: uniformScale))
                    shadAttr = " filter=\"url(#\(fid))\""
                }
                let escaped = te.text
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                shapes.append(
                    "<text x=\"\(f(tx))\" y=\"\(f(fr.minY + fs))\" font-family=\"\(te.fontName)\" font-size=\"\(f(fs))\" font-weight=\"\(fw)\" font-style=\"\(fst)\" fill=\"\(te.textColor.svgHex)\" text-anchor=\"\(anchor)\" opacity=\"\(f(te.opacity))\"\(transform)\(shadAttr)>\(escaped)</text>"
                )
            }
        }

        let w = Int(targetSize.width), h = Int(targetSize.height)
        let defsBlock = defs.isEmpty ? "" : "<defs>\n\(defs.joined(separator: "\n"))\n</defs>"
        let shapesBlock = shapes.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)">
        \(defsBlock)
        \(shapesBlock)
        </svg>
        """
    }

    // MARK: - SVG helpers

    private static func f(_ v: Double) -> String { String(format: "%.2f", v) }
    private static func f(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
    private static func fi(_ v: CGFloat) -> String { "\(Int(v))" }

    private static func frame(_ r: CGRect, scale s: CGFloat, ox: CGFloat, oy: CGFloat) -> CGRect {
        CGRect(x: r.minX * s + ox, y: r.minY * s + oy,
               width: r.width * s, height: r.height * s)
    }

    private static func rotateAttr(_ degrees: Double, cx: CGFloat, cy: CGFloat) -> String {
        guard degrees != 0 else { return "" }
        return String(format: " transform=\"rotate(%.2f %.2f %.2f)\"", degrees, cx, cy)
    }

    private static func svgGradient(id: String, config: GradientConfig,
                                    x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> String
    {
        let stops = config.stops.sorted { $0.location < $1.location }
            .map { "<stop offset=\"\(Int($0.location * 100))%\" stop-color=\"\($0.color.svgHex)\"/>" }
            .joined(separator: "\n  ")
        switch config.type {
        case .linear:
            let r = config.angle * .pi / 180
            let x1 = String(format: "%.3f", 0.5 - sin(r) * 0.5)
            let y1 = String(format: "%.3f", 0.5 - cos(r) * 0.5)
            let x2 = String(format: "%.3f", 0.5 + sin(r) * 0.5)
            let y2 = String(format: "%.3f", 0.5 + cos(r) * 0.5)
            return "<linearGradient id=\"\(id)\" x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" gradientUnits=\"objectBoundingBox\" x=\"\(f(x))\" y=\"\(f(y))\" width=\"\(f(w))\" height=\"\(f(h))\">\n  \(stops)\n</linearGradient>"
        case .radial, .angular:
            return "<radialGradient id=\"\(id)\" cx=\"50%\" cy=\"50%\" r=\"70.71%\">\n  \(stops)\n</radialGradient>"
        }
    }

    private static func svgDropShadow(id: String, shadow: ShadowConfig, scale: CGFloat) -> String {
        let dx = shadow.offsetX * scale
        let dy = shadow.offsetY * scale
        let std = max(shadow.blur * scale / 2, 0)
        return "<filter id=\"\(id)\" x=\"-50%\" y=\"-50%\" width=\"200%\" height=\"200%\"><feDropShadow dx=\"\(f(dx))\" dy=\"\(f(dy))\" stdDeviation=\"\(f(std))\" flood-color=\"\(shadow.color.svgHex)\"/></filter>"
    }

    private static func roundedRectSVG(_ rect: CGRect, radii: CornerRadii,
                                       fill: String, stroke: String, sw: CGFloat,
                                       opacity: Double, extra: String) -> String
    {
        let attrs = "fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(f(sw))\" opacity=\"\(f(opacity))\"\(extra)"
        if radii == .zero {
            return "<rect x=\"\(f(rect.minX))\" y=\"\(f(rect.minY))\" width=\"\(f(rect.width))\" height=\"\(f(rect.height))\" \(attrs)/>"
        }
        if let u = radii.uniformValue {
            return "<rect x=\"\(f(rect.minX))\" y=\"\(f(rect.minY))\" width=\"\(f(rect.width))\" height=\"\(f(rect.height))\" rx=\"\(f(u))\" \(attrs)/>"
        }
        // Per-corner path
        let (x, y, w, h) = (rect.minX, rect.minY, rect.width, rect.height)
        let tl = radii.topLeft, tr = radii.topRight, bl = radii.bottomLeft, br = radii.bottomRight
        let d = "M\(f(x + tl)),\(f(y)) L\(f(x + w - tr)),\(f(y)) Q\(f(x + w)),\(f(y)) \(f(x + w)),\(f(y + tr)) L\(f(x + w)),\(f(y + h - br)) Q\(f(x + w)),\(f(y + h)) \(f(x + w - br)),\(f(y + h)) L\(f(x + bl)),\(f(y + h)) Q\(f(x)),\(f(y + h)) \(f(x)),\(f(y + h - bl)) L\(f(x)),\(f(y + tl)) Q\(f(x)),\(f(y)) \(f(x + tl)),\(f(y)) Z"
        return "<path d=\"\(d)\" \(attrs)/>"
    }
}

// MARK: - Color SVG helpers

private extension Color {
    var svgHex: String {
        guard let nc = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((nc.redComponent * 255).rounded())
        let g = Int((nc.greenComponent * 255).rounded())
        let b = Int((nc.blueComponent * 255).rounded())
        let a = nc.alphaComponent
        if a < 0.001 { return "none" }
        if a >= 0.999 { return String(format: "#%02x%02x%02x", r, g, b) }
        return String(format: "rgba(%d,%d,%d,%.3f)", r, g, b, a)
    }

    var svgFill: String { isTransparentColor ? "none" : svgHex }

    var isTransparentColor: Bool {
        (NSColor(self).usingColorSpace(.sRGB)?.alphaComponent ?? 0) < 0.001
    }
}
