import AppKit

// MARK: - 오버레이 윈도우
/// 한 NSScreen 위에 띄워지는 풀스크린 투명 윈도우.
/// borderless라 기본 키 이벤트를 못 받기에 `canBecomeKey`를 명시 오버라이드한다.
final class SelectionOverlayWindow: NSWindow {

    init(screen: NSScreen) {
        // 5인자 (screen:) init은 designated가 아니므로 4인자 designated를 사용.
        // contentRect를 globalframe으로 주면 윈도우가 자연스럽게 해당 스크린 위에 배치된다.
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.backgroundColor = .clear
        self.isOpaque = false
        // .screenSaver: 메뉴바/Dock보다 위. 풀스크린 앱과는 .fullScreenAuxiliary로 공존.
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false
        self.ignoresMouseEvents = false
    }

    // borderless 윈도우는 기본 false. Esc 등 키 이벤트 수신을 위해 true로.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
