import CoreGraphics

/// The 8 resize handles arranged around a bounding box.
enum ResizeHandle: CaseIterable {
    case topLeft, top, topRight
    case left,        right
    case bottomLeft, bottom, bottomRight

    /// The handle on the opposite side (used as resize anchor).
    var opposite: ResizeHandle {
        switch self {
        case .topLeft:     return .bottomRight
        case .top:         return .bottom
        case .topRight:    return .bottomLeft
        case .left:        return .right
        case .right:       return .left
        case .bottomLeft:  return .topRight
        case .bottom:      return .top
        case .bottomRight: return .topLeft
        }
    }


    /// Range: -0.5 (left/top edge) … +0.5 (right/bottom edge).
    var unitOffset: CGPoint {
        switch self {
        case .topLeft:     return CGPoint(x: -0.5, y: -0.5)
        case .top:         return CGPoint(x:  0.0, y: -0.5)
        case .topRight:    return CGPoint(x:  0.5, y: -0.5)
        case .left:        return CGPoint(x: -0.5, y:  0.0)
        case .right:       return CGPoint(x:  0.5, y:  0.0)
        case .bottomLeft:  return CGPoint(x: -0.5, y:  0.5)
        case .bottom:      return CGPoint(x:  0.0, y:  0.5)
        case .bottomRight: return CGPoint(x:  0.5, y:  0.5)
        }
    }

    /// Canvas-space position of this handle for the given element frame, accounting for rotation.
    func canvasPosition(frame: CGRect, rotation: Double) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let local  = CGPoint(x: unitOffset.x * frame.width,
                             y: unitOffset.y * frame.height)
        return rotateAroundOrigin(local, by: rotation).offsetBy(center)
    }

    // MARK: - Apply resize delta

    /// Returns the new frame after applying `localDelta` (already un-rotated into element space).
    func apply(delta localDelta: CGPoint, to frame: CGRect) -> CGRect {
        var minX = frame.minX, minY = frame.minY
        var maxX = frame.maxX, maxY = frame.maxY

        switch self {
        case .topLeft:     minX += localDelta.x; minY += localDelta.y
        case .top:                                minY += localDelta.y
        case .topRight:    maxX += localDelta.x; minY += localDelta.y
        case .left:        minX += localDelta.x
        case .right:       maxX += localDelta.x
        case .bottomLeft:  minX += localDelta.x; maxY += localDelta.y
        case .bottom:                             maxY += localDelta.y
        case .bottomRight: maxX += localDelta.x; maxY += localDelta.y
        }

        // Enforce minimum size
        let minSize: CGFloat = 4
        if maxX - minX < minSize {
            switch self {
            case .topLeft, .left, .bottomLeft: minX = maxX - minSize
            default:                            maxX = minX + minSize
            }
        }
        if maxY - minY < minSize {
            switch self {
            case .topLeft, .top, .topRight: minY = maxY - minSize
            default:                         maxY = minY + minSize
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Private geometry

private func rotateAroundOrigin(_ v: CGPoint, by degrees: Double) -> CGPoint {
    let r = CGFloat(degrees * .pi / 180)
    return CGPoint(x: v.x * cos(r) - v.y * sin(r),
                   y: v.x * sin(r) + v.y * cos(r))
}

private extension CGPoint {
    func offsetBy(_ other: CGPoint) -> CGPoint {
        CGPoint(x: x + other.x, y: y + other.y)
    }
}
