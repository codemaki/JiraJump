import XCTest
@testable import JiraJump

final class URLBuilderTests: XCTestCase {

    private let sut = URLBuilder()

    // MARK: 정상

    func test_baseURL_끝슬래시포함() throws {
        let url = try sut.issueURL(baseURL: "https://x.com/browse/", issueKey: "PROJ-1")
        XCTAssertEqual(url.absoluteString, "https://x.com/browse/PROJ-1")
    }

    func test_baseURL_끝슬래시없음() throws {
        // 빌더가 슬래시 한 번 추가.
        let url = try sut.issueURL(baseURL: "https://x.com/browse", issueKey: "PROJ-1")
        XCTAssertEqual(url.absoluteString, "https://x.com/browse/PROJ-1")
    }

    func test_baseURL_경로없음() throws {
        // /browse/ 같은 경로 세그먼트는 사용자가 baseURL에 포함시킨다 (빌더는 추가하지 않음).
        let url = try sut.issueURL(baseURL: "https://x.com/", issueKey: "PROJ-1")
        XCTAssertEqual(url.absoluteString, "https://x.com/PROJ-1")
    }

    func test_baseURL_경로없음_슬래시없음() throws {
        let url = try sut.issueURL(baseURL: "https://x.com", issueKey: "PROJ-1")
        XCTAssertEqual(url.absoluteString, "https://x.com/PROJ-1")
    }

    func test_baseURL_공백_트리밍() throws {
        let url = try sut.issueURL(baseURL: "  https://x.com/browse/  ", issueKey: "PROJ-1")
        XCTAssertEqual(url.absoluteString, "https://x.com/browse/PROJ-1")
    }

    // MARK: 에러

    func test_빈_baseURL_에러() {
        XCTAssertThrowsError(
            try sut.issueURL(baseURL: "", issueKey: "PROJ-1")
        ) { error in
            XCTAssertEqual(error as? URLBuilderError, .emptyBaseURL)
        }
    }

    func test_공백만_있는_baseURL_에러() {
        XCTAssertThrowsError(
            try sut.issueURL(baseURL: "   ", issueKey: "PROJ-1")
        ) { error in
            XCTAssertEqual(error as? URLBuilderError, .emptyBaseURL)
        }
    }

    func test_빈_issueKey_에러() {
        XCTAssertThrowsError(
            try sut.issueURL(baseURL: "https://x.com/browse/", issueKey: "")
        ) { error in
            XCTAssertEqual(error as? URLBuilderError, .emptyIssueKey)
        }
    }

    func test_스킴없는_baseURL_에러() {
        XCTAssertThrowsError(
            try sut.issueURL(baseURL: "x.com/browse/", issueKey: "PROJ-1")
        ) { error in
            XCTAssertEqual(error as? URLBuilderError, .invalidBaseURL)
        }
    }
}
