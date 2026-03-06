import SwiftUI

/// 선택된 요소 위에 표시되는 순수 시각적 핸들 오버레이.
/// 실제 제스처는 DesignCanvasView의 단일 gesture가 처리한다.
struct SelectionOverlayView: View {
    let element: CanvasElement
    let zoom: CGFloat

    private let handleSize: CGFloat   = 8
    /// DesignCanvasView의 rotHandleOffset(24/zoom * zoom = 24)과 동일한 view-space 거리
    private let rotHandleDist: CGFloat = 24

    var body: some View {
        ZStack {
            // 점선 테두리
            Rectangle()
                .stroke(Color.accentColor,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))

            // 8개 리사이즈 핸들
            ForEach(ResizeHandle.allCases, id: \.self) { handle in
                resizeHandleView(handle)
            }

            // 회전 핸들 — 우하단 코너에서 대각 24pt 지점
            rotationHandleView
        }
        .frame(width:  element.frame.width  * zoom,
               height: element.frame.height * zoom)
        .rotationEffect(Angle(degrees: element.rotation))
        .position(x: element.frame.midX * zoom,
                  y: element.frame.midY * zoom)
        .allowsHitTesting(false)
    }

    // MARK: - Resize handle

    private func resizeHandleView(_ handle: ResizeHandle) -> some View {
        Rectangle()
            .fill(Color.white)
            .overlay(Rectangle().stroke(Color.accentColor, lineWidth: 1.5))
            .frame(width: handleSize, height: handleSize)
            // unitOffset은 -0.5…0.5, 여기서는 ZStack center 기준 offset
            .offset(x: handle.unitOffset.x * element.frame.width  * zoom,
                    y: handle.unitOffset.y * element.frame.height * zoom)
    }

    // MARK: - Rotation handle
    //
    // 위치: 우하단 코너 (unitOffset = +0.5, +0.5) 에서 (rotHandleDist, rotHandleDist) 더 이동.
    // ZStack center 기준 offset = (+w/2 + 24, +h/2 + 24)
    // → DesignCanvasView.rotationHandleCanvasPos 의 localOffset(w/2+24/zoom, h/2+24/zoom) 와 일치.

    private var rotationHandleView: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(Color.accentColor))
            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            .offset(x: element.frame.width  * zoom / 2 + rotHandleDist,
                    y: element.frame.height * zoom / 2 + rotHandleDist)
    }
}
