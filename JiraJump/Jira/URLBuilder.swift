import Foundation

// MARK: - 에러
enum URLBuilderError: Error, Equatable {
    case emptyBaseURL
    case invalidBaseURL
    case emptyIssueKey
}

// MARK: - 프로토콜
/// Jira 이슈 페이지 URL을 생성한다.
///
/// 경로 구성 방침: 라이브러리는 경로 세그먼트를 임의로 추가하지 않는다.
/// 사용자가 baseURL에 원하는 전체 prefix를 적고(예: `https://jira.skbroadband.com/browse/`),
/// 빌더는 거기에 issueKey만 이어 붙인다. 끝 슬래시는 자동 정규화하여 중복을 방지.
///
/// 예시:
/// - `"https://x.com/browse/"` + `"PROJ-1"` → `"https://x.com/browse/PROJ-1"`
/// - `"https://x.com/browse"`  + `"PROJ-1"` → `"https://x.com/browse/PROJ-1"`
/// - `"https://x.com/"`        + `"PROJ-1"` → `"https://x.com/PROJ-1"`
protocol URLBuilding {
    /// 위 규칙으로 합성된 URL을 반환.
    /// - Throws: `URLBuilderError` (빈 입력, 잘못된 baseURL).
    func issueURL(baseURL: String, issueKey: String) throws -> URL
}

// MARK: - 구현
final class URLBuilder: URLBuilding {

    func issueURL(baseURL: String, issueKey: String) throws -> URL {

        // 공백 트리밍 후 빈 값 차단.
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw URLBuilderError.emptyBaseURL }

        guard !issueKey.isEmpty else { throw URLBuilderError.emptyIssueKey }

        // 끝 슬래시가 있으면 한 번 떼어내고 단일 슬래시로 join → "//key" 같은 중복 방지.
        let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed

        let urlString = "\(normalized)/\(issueKey)"

        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw URLBuilderError.invalidBaseURL
        }
        return url
    }
}
