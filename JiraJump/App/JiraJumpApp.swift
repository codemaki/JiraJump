import SwiftUI

/// JiraJump의 진입점.
///
/// macOS 14+ `MenuBarExtra` 씬을 사용해 Dock 아이콘 없이
/// 메뉴바에만 상주한다. (`LSUIElement=YES`는 project.yml에 설정.)
@main
struct JiraJumpApp: App {

    // MARK: - 의존성
    /// 글로벌 핫키 매니저. App 생애주기 동안 한 번만 생성.
    private let hotkeyManager: HotkeyManaging

    /// 캡처 → OCR → URL 플로우 오케스트레이터. 메뉴와 핫키가 공유.
    private let coordinator: CaptureCoordinator

    /// 권한 안내 윈도우 컨트롤러 (App init에서 자동 노출 가능하도록 AppKit 기반).
    private let permissionsWindowController: PermissionsWindowController

    /// 로그인 항목 등록 서비스 (설정 화면 토글이 시스템 상태와 동기화).
    private let loginItemService: LoginItemServicing

    // MARK: - 초기화
    init() {
        // 의존성 그래프를 진입점에서 한 번 조립한다 (싱글톤 대신 명시적 주입).
        let notificationService = NotificationService()
        let settings = AppSettings()
        let permissionsService = PermissionsService()
        let permissionsWindowController = PermissionsWindowController(service: permissionsService)
        self.permissionsWindowController = permissionsWindowController
        let loginItemService = LoginItemService()
        self.loginItemService = loginItemService

        let coordinator = CaptureCoordinator(
            captureService: ScreenCaptureKitService(),
            ocrService: VisionTextRecognitionService(),
            issueKeyExtractor: IssueKeyExtractor(),
            urlBuilder: URLBuilder(),
            notificationService: notificationService,
            settings: settings,
            permissionsService: permissionsService,
            onPermissionMissing: { [permissionsWindowController] in
                permissionsWindowController.show()
            }
        )
        self.coordinator = coordinator

        let hotkeyManager: HotkeyManaging = HotkeyManager()
        hotkeyManager.register {
            coordinator.start()
        }
        self.hotkeyManager = hotkeyManager

        // 첫 실행에서 한 번 시스템 권한 프롬프트가 뜬다 (이후엔 캐시된 결정 사용).
        Task { await notificationService.requestAuthorization() }

        // 화면 기록 권한 자동 안내: preflight만 호출(실제 TCC 프롬프트는 띄우지 않음).
        // 권한이 없으면 우리 안내 윈도우를 노출. 매 실행마다 검사 — 사용자가 권한을 회수해도 다음 실행에서 안내.
        if !permissionsService.hasScreenCapturePermission {
            Task { @MainActor [permissionsWindowController] in
                // SwiftUI scene 셋업이 끝나도록 잠깐 대기.
                try? await Task.sleep(nanoseconds: 300_000_000)
                permissionsWindowController.show()
            }
        }

        NSLog("[JiraJump] launched, hotkey registered")
    }

    var body: some Scene {

        // MARK: - 메뉴바 아이콘 + 드롭다운 메뉴
        MenuBarExtra {
            MenuContent(
                coordinator: coordinator,
                onShowPermissions: { [permissionsWindowController] in
                    permissionsWindowController.show()
                }
            )
        } label: {
            // SF Symbol. 향후 Step 8에서 커스텀 아이콘으로 교체 가능.
            Image(systemName: "text.viewfinder")
        }

        // MARK: - 설정 윈도우
        // `Settings` scene 대신 `Window`를 쓰는 이유: macOS 13/14의 메뉴 라벨 변경
        // (Preferences → Settings)과 Selector 네이밍 차이를 피하고, 명시적 ID로 열기 위함.
        Window("JiraJump 설정", id: WindowIdentifier.settings) {
            SettingsView(loginItemService: loginItemService)
        }
        .defaultSize(width: 520, height: 460)
    }
}

// MARK: - 윈도우 ID
/// `openWindow(id:)`에 쓰는 식별자.
enum WindowIdentifier {
    static let settings = "settings"
}

// MARK: - 메뉴 콘텐츠
/// 메뉴바 아이콘을 클릭하면 펼쳐지는 메뉴.
private struct MenuContent: View {

    let coordinator: CaptureCoordinator
    let onShowPermissions: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("캡처 시작") {
            coordinator.start()
        }
        // 정적 단축키 표기 생략: 사용자가 핫키를 변경하면 어긋날 수 있어 정직한 미표기를 선택.
        // 글로벌 등록은 HotkeyManager가 사용자 설정대로 자동 갱신.

        Divider()

        Button("권한 설정...") {
            onShowPermissions()
        }

        Button("설정...") {
            openWindow(id: WindowIdentifier.settings)
            // LSUIElement 앱은 윈도우를 열어도 자동으로 전면화되지 않으므로 명시적 활성화.
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("JiraJump 정보") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(options: [
                .applicationName: "JiraJump",
                .credits: NSAttributedString(
                    string: "화면 캡처로 Jira 이슈 키를 빠르게 여는 메뉴바 유틸리티",
                    attributes: [.font: NSFont.systemFont(ofSize: 11)]
                )
            ])
        }

        Divider()

        Button("종료") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
