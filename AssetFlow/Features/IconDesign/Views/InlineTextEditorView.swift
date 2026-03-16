import AppKit
import SwiftUI

/// NSTextView 기반의 캔버스 인라인 텍스트 편집기.
/// 텍스트 도구로 요소를 클릭했을 때 캔버스 위에 오버레이로 표시된다.
///
/// - `onSizeChange`: 텍스트 내용이 바뀔 때 화면 좌표계(pt) 기준 크기(너비·높이)를 보고한다.
struct InlineTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontName: String
    var fontSize: CGFloat   // zoom 적용 후 화면 pt
    var isBold: Bool
    var isItalic: Bool
    var textColor: Color
    var onEndEditing: () -> Void
    var onSizeChange: ((CGSize) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        // 컨테이너 너비·높이 제한 없음 → 텍스트 내용에 따라 자동 확장
        tv.textContainer?.widthTracksTextView  = false
        tv.textContainer?.heightTracksTextView = false
        tv.textContainer?.containerSize = CGSize(
            width:  CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable   = true
        tv.isHorizontallyResizable = true
        tv.autoresizingMask        = []
        tv.textContainerInset = .zero

        context.coordinator.textView = tv
        applyStyle(to: tv)
        tv.string = text

        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
            context.coordinator.reportSize()
        }
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        if !context.coordinator.isEditing, tv.string != text {
            tv.string = text
            applyStyle(to: tv)
            context.coordinator.reportSize()
        } else {
            applyStyle(to: tv)
        }
    }

    // MARK: - Style

    private func applyStyle(to tv: NSTextView) {
        var font = NSFont(name: fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        if isBold   { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)   }
        if isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }

        let ps = NSMutableParagraphStyle()

        tv.font = font
        tv.textColor = NSColor(textColor)
        tv.typingAttributes = [
            .font:           font,
            .foregroundColor: NSColor(textColor),
            .paragraphStyle: ps,
        ]

        // typingAttributes는 새로 입력할 텍스트에만 적용됨.
        // 편집 중 정렬 변경 시 기존 텍스트에도 즉시 반영되도록 textStorage 전체에 적용.
        if let storage = tv.textStorage, storage.length > 0 {
            storage.beginEditing()
            storage.addAttribute(.paragraphStyle, value: ps,
                                 range: NSRange(location: 0, length: storage.length))
            storage.endEditing()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineTextEditor
        weak var textView: NSTextView?
        var isEditing = false

        init(_ parent: InlineTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) { isEditing = true  }
        func textDidEndEditing(_ notification: Notification)   { isEditing = false }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            reportSize()
        }

        func textView(_ tv: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEndEditing()
                return true
            }
            return false
        }

        /// NSTextView 자신의 layoutManager를 사용해 실제 렌더링 크기를 측정한다.
        /// boundingRect보다 정확하게 NSTextView 표시와 일치함.
        func reportSize() {
            guard let tv = textView,
                  let lm = tv.layoutManager,
                  let tc = tv.textContainer else { return }
            lm.ensureLayout(for: tc)

            if tv.string.isEmpty {
                let font = (tv.typingAttributes[.font] as? NSFont) ?? NSFont.systemFont(ofSize: parent.fontSize)
                let lineH = ceil(font.ascender - font.descender + font.leading)
                parent.onSizeChange?(CGSize(width: 1, height: lineH))
                return
            }

            let usedRect = lm.usedRect(for: tc)
            // drawGlyphs(at: .zero) 기준으로 실제 glyphs가 시작하는 위치와 크기를 보고:
            // usedRect.origin이 (0,0)이 아닌 경우 origin offset도 콜백에 포함
            let size = CGSize(width: ceil(usedRect.maxX), height: ceil(usedRect.maxY))
            parent.onSizeChange?(size)
        }
    }
}
