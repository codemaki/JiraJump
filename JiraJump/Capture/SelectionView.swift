import AppKit

// MARK: - 영역 선택 뷰
/// 오버레이 윈도우의 contentView. 마우스 드래그로 사각형을 그리고 Esc로 취소한다.
///
/// 시각 효과: 선택 영역 외 4구역만 dim(검정 30%) → 선택 영역은 원본 화면 그대로 노출 + 흰 테두리.
/// 좌표계: 윈도우 contentView 좌표(좌하단 원점, 포인트). 외부에 글로벌 변환은 RegionSelector에서 수행.
final class SelectionView: NSView {

    /// 드래그 완료 콜백.
    /// - Parameter rect: 윈도우 좌표계 기준 선택 영역. nil이면 사용자 취소(Esc 또는 짧은 클릭).
    var onComplete: ((CGRect?) -> Void)?

    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    // 키 이벤트(특히 Esc) 수신을 위해 firstResponder 자격이 필요.
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: 마우스
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        // 너무 짧은 드래그는 의도치 않은 클릭으로 보고 취소.
        let result: CGRect? = {
            guard let rect = currentRect, rect.width >= 2, rect.height >= 2 else { return nil }
            return rect
        }()
        startPoint = nil
        currentRect = nil
        needsDisplay = true
        onComplete?(result)
    }

    // MARK: 키
    override func keyDown(with event: NSEvent) {
        // Esc keyCode 53.
        if event.keyCode == 53 {
            onComplete?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: 그리기
    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.3)
        dim.setFill()

        guard let rect = currentRect else {
            // 선택 시작 전: 전체 영역 dim.
            bounds.fill()
            return
        }

        // 선택 영역 주변 4구역만 dim (선택 영역은 투명 → 원본 노출).
        let top = NSRect(
            x: 0, y: rect.maxY,
            width: bounds.width, height: bounds.maxY - rect.maxY
        )
        let bottom = NSRect(
            x: 0, y: 0,
            width: bounds.width, height: rect.minY
        )
        let left = NSRect(
            x: 0, y: rect.minY,
            width: rect.minX, height: rect.height
        )
        let right = NSRect(
            x: rect.maxX, y: rect.minY,
            width: bounds.maxX - rect.maxX, height: rect.height
        )
        top.fill()
        bottom.fill()
        left.fill()
        right.fill()

        // 선택 영역 흰 테두리.
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }
}
