import Foundation
import UserNotifications

// MARK: - 프로토콜
/// 사용자 알림 표시를 담당한다.
protocol NotificationServicing {
    /// 권한을 요청한다 (이미 결정된 상태면 즉시 반환).
    /// 첫 호출 시 시스템 프롬프트가 한 번 뜬다.
    func requestAuthorization() async

    /// 즉시 알림을 표시한다.
    func notify(title: String, body: String) async
}

// MARK: - 구현
/// `UNUserNotificationCenter` 래퍼.
final class NotificationService: NotificationServicing {

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        // 알림만 사용. 사운드/배지 미요청으로 권한 범위를 좁게 유지.
        do {
            _ = try await center.requestAuthorization(options: [.alert])
        } catch {
            NSLog("[JiraJump] notification auth error: %@", String(describing: error))
        }
    }

    func notify(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        // trigger=nil → 즉시 표시.
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            NSLog("[JiraJump] notification post error: %@", String(describing: error))
        }
    }
}
