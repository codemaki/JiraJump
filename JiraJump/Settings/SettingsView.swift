import KeyboardShortcuts
import SwiftUI

// MARK: - 설정 화면
/// 별도 윈도우(`Window` scene)로 노출되는 설정 폼.
/// 모든 값은 `@AppStorage`로 즉시 영속화되며, Coordinator는 다음 캡처 시 자동으로 새 값을 읽는다.
/// 자동 시작은 `SMAppService` 시스템 상태가 source of truth이라 별도 `@State`로 동기화.
struct SettingsView: View {

    /// 자동 시작 등록/해제 (시스템 상태와 동기화).
    let loginItemService: LoginItemServicing

    // MARK: 영속 상태
    @AppStorage(AppSettingsKeys.baseURL)
    private var baseURL: String = AppSettingsDefaults.baseURL

    @AppStorage(AppSettingsKeys.ocrLanguageEnglish)
    private var useEnglish: Bool = AppSettingsDefaults.useEnglish

    @AppStorage(AppSettingsKeys.ocrLanguageKorean)
    private var useKorean: Bool = AppSettingsDefaults.useKorean

    @AppStorage(AppSettingsKeys.postCaptureAction)
    private var postCaptureAction: PostCaptureAction = AppSettingsDefaults.postCaptureAction

    @AppStorage(AppSettingsKeys.showMultiMatchPicker)
    private var showMultiMatchPicker: Bool = AppSettingsDefaults.showMultiMatchPicker

    // MARK: 시스템 상태 미러
    @State private var loginItemEnabled: Bool = false

    var body: some View {
        Form {
            Section("Jira") {
                TextField(
                    "Base URL",
                    text: $baseURL,
                    prompt: Text("https://your-jira.example.com/browse/")
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .help("이슈 키 바로 앞까지의 전체 URL을 입력하세요. 끝 슬래시 유무는 자동 처리됩니다.")
            }

            Section("글로벌 핫키") {
                KeyboardShortcuts.Recorder(for: .captureRegion)
            }

            Section("OCR 인식 언어") {
                Toggle("영어 (en-US)", isOn: $useEnglish)
                Toggle("한국어 (ko-KR)", isOn: $useKorean)
            }

            Section("캡처 후 동작") {
                Picker("", selection: $postCaptureAction) {
                    ForEach(PostCaptureAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Toggle("여러 매치 시 선택 UI 표시", isOn: $showMultiMatchPicker)
                    .help("화면에 두 개 이상의 Jira 키가 보일 때, 어느 키를 사용할지 묻는 다이얼로그를 표시합니다. 끄면 첫 번째 매치를 자동 사용.")
            }

            Section("자동 시작") {
                Toggle("로그인 시 JiraJump 자동 실행", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { _, newValue in
                        do {
                            try loginItemService.setEnabled(newValue)
                        } catch {
                            // 실패 시 시스템 실제 상태로 되돌림.
                            NSLog("[JiraJump] login item toggle error: %@", String(describing: error))
                            loginItemEnabled = loginItemService.isEnabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 460)
        .onAppear {
            loginItemEnabled = loginItemService.isEnabled
        }
    }
}
