import SwiftUI

// MARK: - Text alignment

nonisolated enum TextAlignmentOption: Int, CaseIterable {
    case left, center, right

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left:   return .left
        case .center: return .center
        case .right:  return .right
        }
    }

    var sfSymbol: String {
        switch self {
        case .left:   return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right:  return "text.alignright"
        }
    }
}

// MARK: - Text element

nonisolated struct TextElement: Identifiable {
    var id: UUID         = UUID()
    var name: String     = "Text"
    var isVisible: Bool  = true
    var isLocked: Bool   = false
    var opacity: Double  = 1.0
    var rotation: Double = 0   // degrees
    var frame: CGRect
    var text: String     = ""
    var fontName: String = "Helvetica"
    var fontSize: CGFloat = 100
    var isBold: Bool     = false
    var isItalic: Bool   = false
    var textColor: Color = .black
    var alignment: TextAlignmentOption = .left
    var shadow: ShadowConfig? = nil
    
    func show() {
        print("TextElement: \(text) at \(frame.origin), font: \(fontName) \(fontSize)pt, color: \(textColor), alignment: \(alignment)")
    }
}

// MARK: - Corner radii

nonisolated struct CornerRadii: Equatable {
    var topLeft:     CGFloat = 0
    var topRight:    CGFloat = 0
    var bottomLeft:  CGFloat = 0
    var bottomRight: CGFloat = 0

    static let zero = CornerRadii()

    var isUniform: Bool {
        topLeft == topRight && topLeft == bottomLeft && topLeft == bottomRight
    }
    var uniformValue: CGFloat? { isUniform ? topLeft : nil }

    /// 4 개 모두 동일한 값으로 초기화
    init(_ uniform: CGFloat = 0) {
        topLeft = uniform; topRight = uniform
        bottomLeft = uniform; bottomRight = uniform
    }
    init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        self.topLeft = topLeft; self.topRight = topRight
        self.bottomLeft = bottomLeft; self.bottomRight = bottomRight
    }

    /// zoom 배율 적용
    func scaled(by z: CGFloat) -> CornerRadii {
        CornerRadii(topLeft: topLeft * z, topRight: topRight * z,
                    bottomLeft: bottomLeft * z, bottomRight: bottomRight * z)
    }
}

// MARK: - Shadow

nonisolated struct ShadowConfig: Equatable {
    var color:   Color   = Color.black.opacity(0.35)
    var blur:    CGFloat = 6
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 4
}

// MARK: - Leaf element types

nonisolated struct ShapeElement: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool  = true
    var isLocked: Bool   = false
    var opacity: Double  = 1.0
    var rotation: Double = 0   // degrees
    var frame: CGRect
    var shapeType: ShapeType
    var fillColor: Color
    var strokeColor: Color
    var strokeWidth: CGFloat
    var cornerRadii: CornerRadii = CornerRadii()
    var shadow: ShadowConfig?   = nil

    /// 단일 반경 접근 (backward compat / uniform 체크 용도)
    var cornerRadius: CGFloat {
        get { cornerRadii.uniformValue ?? 0 }
        set { cornerRadii = CornerRadii(newValue) }
    }

    nonisolated enum ShapeType { case rectangle, ellipse }
}

nonisolated struct PathElement: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool  = true
    var isLocked: Bool   = false
    var opacity: Double  = 1.0
    var rotation: Double = 0   // degrees, rotates around bounding-box center
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var shadow: ShadowConfig? = nil

    var frame: CGRect {
        guard !points.isEmpty else { return .zero }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!,
                      width: xs.max()! - xs.min()!,
                      height: ys.max()! - ys.min()!)
    }
}

nonisolated struct ImageElement: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool  = true
    var isLocked: Bool   = false
    var opacity: Double  = 1.0
    var rotation: Double = 0   // degrees
    var frame: CGRect
    var image: NSImage
    var shadow: ShadowConfig? = nil
}

// MARK: - Wrapper enum for polymorphic storage

nonisolated enum CanvasElement: Identifiable {
    case shape(ShapeElement)
    case path(PathElement)
    case image(ImageElement)
    case text(TextElement)

    var id: UUID {
        switch self {
        case .shape(let e): e.id
        case .path(let e):  e.id
        case .image(let e): e.id
        case .text(let e):  e.id
        }
    }

    var name: String {
        get {
            switch self {
            case .shape(let e): e.name
            case .path(let e):  e.name
            case .image(let e): e.name
            case .text(let e):  e.name
            }
        }
        set {
            switch self {
            case .shape(var e): e.name = newValue; self = .shape(e)
            case .path(var e):  e.name = newValue; self = .path(e)
            case .image(var e): e.name = newValue; self = .image(e)
            case .text(var e):  e.name = newValue; self = .text(e)
            }
        }
    }

    var isVisible: Bool {
        get {
            switch self {
            case .shape(let e): e.isVisible
            case .path(let e):  e.isVisible
            case .image(let e): e.isVisible
            case .text(let e):  e.isVisible
            }
        }
        set {
            switch self {
            case .shape(var e): e.isVisible = newValue; self = .shape(e)
            case .path(var e):  e.isVisible = newValue; self = .path(e)
            case .image(var e): e.isVisible = newValue; self = .image(e)
            case .text(var e):  e.isVisible = newValue; self = .text(e)
            }
        }
    }

    var frame: CGRect {
        switch self {
        case .shape(let e): e.frame
        case .path(let e):  e.frame
        case .image(let e): e.frame
        case .text(let e):  e.frame
        }
    }

    var opacity: Double {
        get {
            switch self {
            case .shape(let e): e.opacity
            case .path(let e):  e.opacity
            case .image(let e): e.opacity
            case .text(let e):  e.opacity
            }
        }
        set {
            switch self {
            case .shape(var e): e.opacity = newValue; self = .shape(e)
            case .path(var e):  e.opacity = newValue; self = .path(e)
            case .image(var e): e.opacity = newValue; self = .image(e)
            case .text(var e):  e.opacity = newValue; self = .text(e)
            }
        }
    }

    var rotation: Double {
        get {
            switch self {
            case .shape(let e): e.rotation
            case .path(let e):  e.rotation
            case .image(let e): e.rotation
            case .text(let e):  e.rotation
            }
        }
        set {
            switch self {
            case .shape(var e): e.rotation = newValue; self = .shape(e)
            case .path(var e):  e.rotation = newValue; self = .path(e)
            case .image(var e): e.rotation = newValue; self = .image(e)
            case .text(var e):  e.rotation = newValue; self = .text(e)
            }
        }
    }

    var shadow: ShadowConfig? {
        get {
            switch self {
            case .shape(let e): e.shadow
            case .path(let e):  e.shadow
            case .image(let e): e.shadow
            case .text(let e):  e.shadow
            }
        }
        set {
            switch self {
            case .shape(var e): e.shadow = newValue; self = .shape(e)
            case .path(var e):  e.shadow = newValue; self = .path(e)
            case .image(var e): e.shadow = newValue; self = .image(e)
            case .text(var e):  e.shadow = newValue; self = .text(e)
            }
        }
    }

    // MARK: - Rotation-aware hit testing

    func containsPoint(_ point: CGPoint, tolerance: CGFloat = 4) -> Bool {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let local  = rotated(CGPoint(x: point.x - center.x, y: point.y - center.y),
                             by: -rotation)
        return abs(local.x) <= frame.width  / 2 + tolerance
            && abs(local.y) <= frame.height / 2 + tolerance
    }

    // MARK: - Duplication (new UUID, offset position)

    func duplicated(offset: CGFloat = 8) -> CanvasElement {
        switch self {
        case .shape(let e):
            var copy = e
            copy = ShapeElement(
                id: UUID(), name: e.name + " Copy",
                isVisible: e.isVisible, isLocked: e.isLocked,
                opacity: e.opacity, rotation: e.rotation,
                frame: e.frame.offsetBy(dx: offset, dy: offset),
                shapeType: e.shapeType,
                fillColor: e.fillColor, strokeColor: e.strokeColor,
                strokeWidth: e.strokeWidth, cornerRadii: e.cornerRadii,
                shadow: e.shadow)
            return .shape(copy)
        case .path(let e):
            let moved = PathElement(
                id: UUID(), name: e.name + " Copy",
                isVisible: e.isVisible, isLocked: e.isLocked,
                opacity: e.opacity, rotation: e.rotation,
                points: e.points.map { CGPoint(x: $0.x + offset, y: $0.y + offset) },
                color: e.color, lineWidth: e.lineWidth, shadow: e.shadow)
            return .path(moved)
        case .image(let e):
            let moved = ImageElement(
                id: UUID(), name: e.name + " Copy",
                isVisible: e.isVisible, isLocked: e.isLocked,
                opacity: e.opacity, rotation: e.rotation,
                frame: e.frame.offsetBy(dx: offset, dy: offset),
                image: e.image, shadow: e.shadow)
            return .image(moved)
        case .text(let e):
            var copy = e
            copy.id = UUID()
            copy.name = e.name + " Copy"
            copy.frame = e.frame.offsetBy(dx: offset, dy: offset)
            return .text(copy)
        }
    }

    // MARK: - Private geometry helper

    private func rotated(_ v: CGPoint, by degrees: Double) -> CGPoint {
        let r   = CGFloat(degrees * .pi / 180)
        let cos = Foundation.cos(r), sin = Foundation.sin(r)
        return CGPoint(x: v.x * cos - v.y * sin, y: v.x * sin + v.y * cos)
    }
}
