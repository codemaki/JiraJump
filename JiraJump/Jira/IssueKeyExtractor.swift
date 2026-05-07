import Foundation

// MARK: - 프로토콜
/// 텍스트에서 Jira 이슈 키(`PROJ-1234` 형태)를 추출한다.
protocol IssueKeyExtracting {
    /// 첫 번째 매치를 반환. 없으면 nil.
    func firstMatch(in text: String) -> String?

    /// 매치된 모든 키 (등장 순서). Step 8의 다중 매치 선택 UI에서 사용.
    func allMatches(in text: String) -> [String]
}

// MARK: - 구현
/// 정규식 `\b[A-Z][A-Z0-9]+-\d+\b` 기반 추출기.
///
/// 패턴 의도:
/// - 첫 글자: 대문자 알파벳 (소문자/숫자로 시작 차단)
/// - 두 번째 이후 1+자: 대문자 알파벳/숫자 (Jira 프로젝트 키는 보통 2자 이상)
/// - 하이픈 + 숫자 1자 이상
/// - 양 끝 단어 경계로 부분 매치 방지 (예: `MYPROJ-12-extra`에서 `PROJ-12`만 잡히지 않음)
final class IssueKeyExtractor: IssueKeyExtracting {

    private let regex: NSRegularExpression

    init() {
        // 패턴은 컴파일 타임에 검증된 상수.
        // try!: 잘못된 패턴이면 즉시 크래시가 정상 동작 (런타임 추출 시 silent fail보다 낫다).
        self.regex = try! NSRegularExpression(pattern: #"\b[A-Z][A-Z0-9]+-\d+\b"#)
    }

    func firstMatch(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let r = Range(match.range, in: text)
        else { return nil }
        return String(text[r])
    }

    func allMatches(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
