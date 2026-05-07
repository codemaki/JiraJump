import AppKit

// MARK: - 영역 선택 오케스트레이터
/// 모든 NSScreen에 오버레이를 띄우고 사용자 영역 선택을 비동기로 처리한다.
/// 결과는 글로벌 스크린 좌표계의 CGRect (좌하단 원점, 포인트). nil이면 사용자 취소.
@MainActor
final class RegionSelector {

    private var windows: [SelectionOverlayWindow] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?

    /// 영역 선택 UI를 띄우고 사용자 입력을 기다린다.
    /// 동시에 두 번 호출되면 두 번째는 즉시 nil을 반환(중복 표시 방지).
    func selectRegion() async -> CGRect? {
        guard continuation == nil else { return nil }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        return await withCheckedContinuation { (cont: CheckedContinuation<CGRect?, Never>) in
            self.continuation = cont

            for screen in screens {
                let window = SelectionOverlayWindow(screen: screen)

                // contentView는 (0,0)에서 시작하는 윈도우-로컬 좌표.
                let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
                view.onComplete = { [weak self, weak window] localRect in
                    guard let self else { return }
                    // 윈도우-로컬 → 글로벌 스크린 좌표로 변환.
                    let globalRect = localRect.flatMap { window?.convertToScreen($0) }
                    self.finish(with: globalRect)
                }
                window.contentView = view
                window.makeFirstResponder(view)
                window.orderFrontRegardless()
                windows.append(window)
            }

            // LSUIElement 앱은 자동 활성화되지 않음. Esc 등 키 이벤트 수신 위해 명시.
            NSApp.activate(ignoringOtherApps: true)
            // 첫 윈도우를 key로 만들어 키 이벤트 수신.
            windows.first?.makeKey()
        }
    }

    /// 결과 확정(성공 또는 취소). 모든 오버레이 정리.
    private func finish(with rect: CGRect?) {
        guard let cont = continuation else { return }
        continuation = nil

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()

        cont.resume(returning: rect)
    }
}
