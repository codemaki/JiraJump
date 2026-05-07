import AppKit
import CoreGraphics

// MARK: - 프로토콜
/// 화면 기록(Screen Recording) 권한 상태 확인 및 시스템 UI 호출.
protocol PermissionsServicing {
    /// 현재 화면 기록 권한 보유 여부. 시스템 프롬프트는 띄우지 않음 (preflight).
    var hasScreenCapturePermission: Bool { get }

    /// TCC 프롬프트를 트리거. **첫 호출에서만** 시스템 다이얼로그가 뜨고,
    /// 이미 결정된 상태(허용/거부)에선 단순히 현재 상태만 반환한다.
    /// 거부된 상태에서 변경하려면 사용자가 시스템 설정으로 직접 가야 한다.
    @discardableResult
    func requestScreenCapturePermission() -> Bool

    /// 시스템 설정 → 개인정보 보호 → 화면 기록 패널을 연다.
    func openSystemSettings()
}

// MARK: - 구현
final class PermissionsService: PermissionsServicing {

    var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    func requestScreenCapturePermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        // macOS 13+의 시스템 설정 URL 스킴.
        // 화면 기록 패널로 직접 이동.
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
