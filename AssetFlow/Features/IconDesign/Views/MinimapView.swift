import SwiftUI

/// A minimap overlay that shows the entire canvas and highlights the
/// currently visible viewport area with a red-bordered rectangle.
/// Clicking or dragging on the minimap pans the canvas to that position.
struct MinimapView: View {
    let canvasSize: CGSize
    let zoom: CGFloat
    @Binding var canvasOffset: CGSize
    let viewportSize: CGSize

    // Fixed display width; height is derived from canvas aspect ratio.
    private let displayWidth: CGFloat = 160

    private var displayHeight: CGFloat {
        displayWidth * canvasSize.height / canvasSize.width
    }

    /// Scale factor: minimap pixels per canvas pixel
    private var scale: CGFloat {
        displayWidth / canvasSize.width
    }

    /// The visible area of the canvas expressed in canvas coordinates,
    /// clamped to the canvas bounds so the indicator never overflows the minimap.
    private var visibleRect: CGRect {
        let raw = CGRect(
            x: canvasSize.width  / 2 - viewportSize.width  / (2 * zoom) - canvasOffset.width  / zoom,
            y: canvasSize.height / 2 - viewportSize.height / (2 * zoom) - canvasOffset.height / zoom,
            width:  viewportSize.width  / zoom,
            height: viewportSize.height / zoom
        )
        let canvasBounds = CGRect(origin: .zero, size: canvasSize)
        let clamped = raw.intersection(canvasBounds)
        return clamped.isNull ? canvasBounds : clamped
    }

    /// The visible rect mapped to minimap coordinates.
    private var viewportRectInMinimap: CGRect {
        CGRect(
            x: visibleRect.minX * scale,
            y: visibleRect.minY * scale,
            width:  visibleRect.width  * scale,
            height: visibleRect.height * scale
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Canvas background
            Rectangle()
                .fill(Color(nsColor: .underPageBackgroundColor))

            // Canvas area
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: displayWidth, height: displayHeight)

            // Viewport indicator
            Rectangle()
                .stroke(Color.red, lineWidth: 1.5)
                .frame(
                    width:  max(2, viewportRectInMinimap.width),
                    height: max(2, viewportRectInMinimap.height)
                )
                .offset(
                    x: viewportRectInMinimap.minX,
                    y: viewportRectInMinimap.minY
                )
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
}

