import Foundation

// MARK: - 키 상수
/// `@AppStorage` / `UserDefaults` 키 모음.
/// 컴파일 타임 상수로 묶어 오타·중복 방지. 뷰 쪽 `@AppStorage`와 런타임 `AppSettings`가 동일 키 공유.
enum AppSettingsKeys {
    static let baseURL = "baseURL"
    static let ocrLanguageEnglish = "ocrLanguage.english"
    static let ocrLanguageKorean = "ocrLanguage.korean"
    static let postCaptureAction = "postCaptureAction"
    static let showMultiMatchPicker = "showMultiMatchPicker"
}

// MARK: - 캡처 후 동작
/// 이슈 키 매치 성공 시 어떤 액션을 수행할지.
/// `@AppStorage`에 저장 가능하도록 RawRepresentable(String) 채택.
enum PostCaptureAction: String, CaseIterable, Identifiable {
    case openURL
    case copyToClipboard
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openURL: return "URL 열기"
        case .copyToClipboard: return "클립보드 복사"
        case .both: return "둘 다"
        }
    }
}

// MARK: - 기본값
/// 처음 실행 시 또는 키가 비었을 때 사용되는 기본값.
/// 뷰의 `@AppStorage` 디폴트와 런타임 `AppSettings`가 동일 값을 보도록 한 곳에 집중.
enum AppSettingsDefaults {
    /// baseURL은 issueKey 앞까지의 전체 prefix를 사용자가 직접 적는다.
    /// (URLBuilder는 경로 세그먼트를 추가하지 않으며 끝 슬래시만 정규화.)
    static let baseURL = "https://jira.skbroadband.com/browse/"
    static let useEnglish = true
    static let useKorean = false
    static let postCaptureAction: PostCaptureAction = .openURL
    static let showMultiMatchPicker = false
}

// MARK: - 프로토콜
/// 런타임 설정값 읽기 인터페이스.
/// Coordinator가 매 호출마다 최신 값을 읽어 캡처 동작에 즉시 반영.
protocol AppSettingsReading {
    var baseURL: String { get }
    var ocrLanguages: [String] { get }
    var postCaptureAction: PostCaptureAction { get }
    var showMultiMatchPicker: Bool { get }
}

// MARK: - 구현
/// `UserDefaults` 기반 어댑터.
/// SwiftUI 측의 `@AppStorage` 변경이 즉시 보이게 하려면 매번 `defaults`에서 새로 읽는다.
final class AppSettings: AppSettingsReading {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var baseURL: String {
        let stored = defaults.string(forKey: AppSettingsKeys.baseURL) ?? AppSettingsDefaults.baseURL
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        // 사용자가 빈 문자열로 만들면 기본값으로 보호.
        return trimmed.isEmpty ? AppSettingsDefaults.baseURL : trimmed
    }

    var ocrLanguages: [String] {
        // 키가 없으면(초기 실행) 기본값 적용.
        let useEnglish = (defaults.object(forKey: AppSettingsKeys.ocrLanguageEnglish) as? Bool)
            ?? AppSettingsDefaults.useEnglish
        let useKorean = (defaults.object(forKey: AppSettingsKeys.ocrLanguageKorean) as? Bool)
            ?? AppSettingsDefaults.useKorean

        var langs: [String] = []
        if useEnglish { langs.append("en-US") }
        if useKorean { langs.append("ko-KR") }
        // 둘 다 끈 상태에서 OCR이 빈 결과를 내지 않도록 영어로 폴백.
        return langs.isEmpty ? ["en-US"] : langs
    }

    var postCaptureAction: PostCaptureAction {
        let raw = defaults.string(forKey: AppSettingsKeys.postCaptureAction)
        return raw.flatMap(PostCaptureAction.init(rawValue:)) ?? AppSettingsDefaults.postCaptureAction
    }

    var showMultiMatchPicker: Bool {
        (defaults.object(forKey: AppSettingsKeys.showMultiMatchPicker) as? Bool)
            ?? AppSettingsDefaults.showMultiMatchPicker
    }
}
