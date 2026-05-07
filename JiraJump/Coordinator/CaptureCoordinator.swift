import AppKit
import Foundation

// MARK: - 캡처 플로우 오케스트레이터
/// "캡처 시작" 트리거를 받아 캡처 → OCR → 이슈 키 추출 → URL 호출/복사 → 알림까지 잇는 단일 진입점.
/// 메뉴 항목과 글로벌 핫키 양쪽이 같은 인스턴스의 `start()`를 호출한다.
///
/// 설정값(baseURL, OCR 언어, 캡처 후 동작)은 `AppSettingsReading`을 통해 매 호출마다 최신 값을 읽으므로,
/// 사용자가 설정 화면에서 변경하면 다음 캡처부터 즉시 반영된다.
final class CaptureCoordinator {

    private let captureService: ScreenCaptureServicing
    private let ocrService: TextRecognitionServicing
    private let issueKeyExtractor: IssueKeyExtracting
    private let urlBuilder: URLBuilding
    private let notificationService: NotificationServicing
    private let settings: AppSettingsReading
    private let permissionsService: PermissionsServicing
    private let onPermissionMissing: @MainActor () -> Void

    init(
        captureService: ScreenCaptureServicing,
        ocrService: TextRecognitionServicing,
        issueKeyExtractor: IssueKeyExtracting,
        urlBuilder: URLBuilding,
        notificationService: NotificationServicing,
        settings: AppSettingsReading,
        permissionsService: PermissionsServicing,
        onPermissionMissing: @escaping @MainActor () -> Void
    ) {
        self.captureService = captureService
        self.ocrService = ocrService
        self.issueKeyExtractor = issueKeyExtractor
        self.urlBuilder = urlBuilder
        self.notificationService = notificationService
        self.settings = settings
        self.permissionsService = permissionsService
        self.onPermissionMissing = onPermissionMissing
    }

    /// 캡처 → OCR → 키 추출 → 액션(열기/복사/둘 다) / 실패 알림을 비동기로 시작한다.
    func start() {
        NSLog("[JiraJump] capture start")

        // 권한 부재 시 캡처 시도 차단 + 권한 안내 윈도우 노출.
        guard permissionsService.hasScreenCapturePermission else {
            NSLog("[JiraJump] capture aborted: missing screen recording permission")
            Task { @MainActor [onPermissionMissing] in
                onPermissionMissing()
            }
            return
        }

        Task { [self] in
            do {
                guard let image = try await captureService.captureInteractive() else {
                    NSLog("[JiraJump] capture cancelled by user")
                    return
                }

                let text = try await ocrService.recognize(
                    image: image,
                    languages: settings.ocrLanguages
                )
                NSLog("[JiraJump] OCR result: %@", text.isEmpty ? "(empty)" : text)

                let allMatches = issueKeyExtractor.allMatches(in: text)
                guard !allMatches.isEmpty else {
                    NSLog("[JiraJump] no issue key found")
                    await notificationService.notify(
                        title: "JiraJump",
                        body: "이슈 키를 찾지 못했습니다"
                    )
                    return
                }

                let issueKey: String
                if allMatches.count > 1 && settings.showMultiMatchPicker {
                    // 사용자에게 어느 키를 쓸지 물어봄. 취소 시 종료.
                    guard let chosen = await Self.pickMatch(from: allMatches) else {
                        NSLog("[JiraJump] multi-match picker cancelled")
                        return
                    }
                    issueKey = chosen
                } else {
                    issueKey = allMatches[0]
                }

                let url = try urlBuilder.issueURL(
                    baseURL: settings.baseURL,
                    issueKey: issueKey
                )
                NSLog("[JiraJump] resolved %@", url.absoluteString)

                let action = settings.postCaptureAction
                await Self.perform(action: action, url: url)
                await notificationService.notify(
                    title: "JiraJump",
                    body: Self.successMessage(for: action, issueKey: issueKey)
                )

            } catch {
                NSLog("[JiraJump] error: %@", String(describing: error))
                await notificationService.notify(
                    title: "JiraJump",
                    body: "오류가 발생했습니다: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - 액션 실행
    /// 사용자 설정에 따라 URL 열기/복사/둘 다를 메인 액터에서 실행.
    @MainActor
    private static func perform(action: PostCaptureAction, url: URL) {
        switch action {
        case .openURL:
            NSWorkspace.shared.open(url)
        case .copyToClipboard:
            copyToClipboard(url.absoluteString)
        case .both:
            // 클립보드 먼저: 브라우저로 포커스 이동 직전에 안전하게 복사 완료.
            copyToClipboard(url.absoluteString)
            NSWorkspace.shared.open(url)
        }
    }

    @MainActor
    private static func copyToClipboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    private static func successMessage(for action: PostCaptureAction, issueKey: String) -> String {
        switch action {
        case .openURL: return "이슈 \(issueKey) 페이지를 엽니다"
        case .copyToClipboard: return "이슈 \(issueKey) 링크를 복사했습니다"
        case .both: return "이슈 \(issueKey) 페이지를 열고 링크를 복사했습니다"
        }
    }

    // MARK: - 다중 매치 선택
    /// 매치된 이슈 키 목록에서 하나를 사용자가 고르도록 NSAlert를 띄운다.
    /// 너무 많으면 8개로 제한 (NSAlert 버튼 시인성).
    @MainActor
    private static func pickMatch(from keys: [String]) -> String? {
        let alert = NSAlert()
        alert.messageText = "여러 이슈 키가 발견되었습니다"
        alert.informativeText = "어느 키를 사용할까요?"

        let displayed = Array(keys.prefix(8))
        for key in displayed {
            alert.addButton(withTitle: key)
        }
        alert.addButton(withTitle: "취소")

        // LSUIElement 앱은 모달도 자동 전면화되지 않으므로 명시 활성화.
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        let firstButton = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        let index = response.rawValue - firstButton
        return (0..<displayed.count).contains(index) ? displayed[index] : nil
    }
}
