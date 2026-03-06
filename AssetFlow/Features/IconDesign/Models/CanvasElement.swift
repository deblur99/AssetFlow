import SwiftUI

// MARK: - Leaf element types

nonisolated struct ShapeElement: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool = true
    var isLocked: Bool  = false
    var opacity: Double = 1.0
    var frame: CGRect
    var shapeType: ShapeType
    var fillColor: Color
    var strokeColor: Color
    var strokeWidth: CGFloat
    var cornerRadius: CGFloat = 0

    nonisolated enum ShapeType { case rectangle, ellipse }
}

nonisolated struct PathElement: Identifiable {
    let id: UUID
    var name: String
    var isVisible: Bool = true
    var isLocked: Bool  = false
    var opacity: Double = 1.0
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat

    /// Bounding box computed from the stroke points.
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
    var isVisible: Bool = true
    var isLocked: Bool  = false
    var opacity: Double = 1.0
    var frame: CGRect
    var image: NSImage
}

// MARK: - Wrapper enum for polymorphic storage

nonisolated enum CanvasElement: Identifiable {
    case shape(ShapeElement)
    case path(PathElement)
    case image(ImageElement)

    var id: UUID {
        switch self {
        case .shape(let e): e.id
        case .path(let e):  e.id
        case .image(let e): e.id
        }
    }

    var name: String {
        get {
            switch self {
            case .shape(let e): e.name
            case .path(let e):  e.name
            case .image(let e): e.name
            }
        }
        set {
            switch self {
            case .shape(var e): e.name = newValue; self = .shape(e)
            case .path(var e):  e.name = newValue; self = .path(e)
            case .image(var e): e.name = newValue; self = .image(e)
            }
        }
    }

    var isVisible: Bool {
        get {
            switch self {
            case .shape(let e): e.isVisible
            case .path(let e):  e.isVisible
            case .image(let e): e.isVisible
            }
        }
        set {
            switch self {
            case .shape(var e): e.isVisible = newValue; self = .shape(e)
            case .path(var e):  e.isVisible = newValue; self = .path(e)
            case .image(var e): e.isVisible = newValue; self = .image(e)
            }
        }
    }

    var frame: CGRect {
        switch self {
        case .shape(let e): e.frame
        case .path(let e):  e.frame
        case .image(let e): e.frame
        }
    }

    var opacity: Double {
        get {
            switch self {
            case .shape(let e): e.opacity
            case .path(let e):  e.opacity
            case .image(let e): e.opacity
            }
        }
        set {
            switch self {
            case .shape(var e): e.opacity = newValue; self = .shape(e)
            case .path(var e):  e.opacity = newValue; self = .path(e)
            case .image(var e): e.opacity = newValue; self = .image(e)
            }
        }
    }
}
