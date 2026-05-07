import Foundation
import ServiceManagement

// MARK: - 프로토콜
/// 로그인 시 자동 시작 등록/해제.
/// `SMAppService` 호출이 메인 스레드 한정이라 프로토콜도 `@MainActor`로 격리.
@MainActor
protocol LoginItemServicing {
    /// 현재 로그인 항목 등록 상태.
    var isEnabled: Bool { get }

    /// 등록 또는 해제.
    /// - Throws: SMAppService가 던지는 시스템 에러 (예: 권한 거부, 미서명 빌드 등).
    func setEnabled(_ enabled: Bool) throws
}

// MARK: - 구현
/// `SMAppService.mainApp` 기반. 별도 헬퍼 번들 없이 메인 앱 자체를 로그인 항목으로 등록.
///
/// 주의: ad-hoc 서명(`-`) 빌드에선 `register()`가 성공해도 macOS가 다음 부팅에서 무시할 수 있다.
/// 정식 배포 시점엔 Developer ID 서명 + 공증이 필요.
@MainActor
final class LoginItemService: LoginItemServicing {

    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
