import AppKit
import KeyboardShortcuts

// MARK: - 핫키 식별자
extension KeyboardShortcuts.Name {
    /// 영역 캡처 트리거 핫키.
    /// 라이브러리가 키 이름("captureRegion")으로 UserDefaults에 사용자 설정을 영속화한다.
    /// 사용자가 한 번이라도 변경하면 default 값은 무시되고 저장된 값이 사용된다.
    static let captureRegion = Self(
        "captureRegion",
        default: .init(.j, modifiers: [.command, .shift])
    )
}

// MARK: - 프로토콜
/// 글로벌 핫키 등록을 추상화한다.
/// 테스트나 대체 구현(예: Carbon RegisterEventHotKey 직접 사용)을 쉽게 끼워 넣기 위함.
protocol HotkeyManaging: AnyObject {
    /// 핫키가 눌릴 때 호출할 액션을 등록한다.
    /// 같은 이름으로 두 번 호출하면 직전 핸들러를 대체한다(중복 호출 방지).
    func register(action: @escaping () -> Void)

    /// 모든 핸들러를 해제한다.
    func unregister()
}

// MARK: - 구현체
/// `KeyboardShortcuts` 라이브러리를 감싸는 기본 구현.
final class HotkeyManager: HotkeyManaging {

    /// 중복 등록 방지를 위해 라이브러리 핸들러를 한 번만 설치하고,
    /// 실제 액션은 이 변수로 갈아 끼운다.
    private var currentAction: (() -> Void)?
    private var didInstallHandler = false

    func register(action: @escaping () -> Void) {
        currentAction = action

        guard !didInstallHandler else { return }
        didInstallHandler = true

        // 라이브러리 핸들러는 한 번만 등록. 실제 동작은 currentAction을 통해 디스패치.
        // 메인 스레드에서 동작 (라이브러리가 보장).
        KeyboardShortcuts.onKeyDown(for: .captureRegion) { [weak self] in
            self?.currentAction?()
        }
    }

    func unregister() {
        currentAction = nil
        KeyboardShortcuts.removeAllHandlers()
        didInstallHandler = false
    }
}
