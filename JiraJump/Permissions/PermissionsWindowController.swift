import AppKit
import SwiftUI

// MARK: - 권한 윈도우 컨트롤러
/// `PermissionsView`를 `NSHostingController` + `NSWindow`로 띄우는 헬퍼.
///
/// SwiftUI `Window` scene 대신 AppKit으로 직접 만든 이유:
/// - App init 시점에 권한 부재 자동 감지 → 즉시 노출이 필요한데
///   `openWindow` 환경값은 View 트리 안에서만 접근 가능해 init에서 호출 불가.
/// - 컨트롤러를 인스턴스로 들고 있으면 Coordinator에서도 같은 윈도우를 깨끗하게 재사용 가능.
@MainActor
final class PermissionsWindowController {

    private let service: PermissionsServicing
    private var window: NSWindow?

    init(service: PermissionsServicing) {
        self.service = service
    }

    /// 윈도우를 표시한다 (이미 떠 있으면 활성화만).
    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = PermissionsView(
            service: service,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = "JiraJump 권한 설정"
        win.styleMask = [.titled, .closable]
        // 닫아도 컨트롤러가 다시 show()하면 재사용할 수 있도록 release 방지.
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        // LSUIElement 앱은 자동 활성화되지 않으므로 명시적 활성화 필요.
        NSApp.activate(ignoringOtherApps: true)

        window = win
    }

    func close() {
        window?.close()
    }
}
