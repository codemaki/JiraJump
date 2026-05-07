import XCTest
@testable import JiraJump

final class IssueKeyExtractorTests: XCTestCase {

    private let sut = IssueKeyExtractor()

    // MARK: firstMatch

    func test_firstMatch_정상_매치() {
        XCTAssertEqual(sut.firstMatch(in: "버그 리포트 PROJ-123 확인 부탁"), "PROJ-123")
    }

    func test_firstMatch_다중매치_첫번째() {
        XCTAssertEqual(sut.firstMatch(in: "PROJ-1 ABC-22 XYZ-333"), "PROJ-1")
    }

    func test_firstMatch_매치_없음() {
        XCTAssertNil(sut.firstMatch(in: "hello world"))
    }

    func test_firstMatch_소문자_무시() {
        XCTAssertNil(sut.firstMatch(in: "proj-123"))
    }

    func test_firstMatch_숫자시작_프로젝트키_무시() {
        XCTAssertNil(sut.firstMatch(in: "123-456"))
    }

    func test_firstMatch_빈_문자열() {
        XCTAssertNil(sut.firstMatch(in: ""))
    }

    func test_firstMatch_단일문자_프로젝트키_무시() {
        // 정규식이 [A-Z][A-Z0-9]+를 요구하므로 최소 2자 필요.
        XCTAssertNil(sut.firstMatch(in: "A-1"))
    }

    func test_firstMatch_프로젝트키에_숫자포함() {
        // 두 번째 글자 이후엔 숫자도 허용.
        XCTAssertEqual(sut.firstMatch(in: "ABC2-99"), "ABC2-99")
    }

    func test_firstMatch_단어경계_보호() {
        // 단어 경계 \b 덕분에 부분 매치되지 않음.
        XCTAssertEqual(sut.firstMatch(in: "MYPROJ-12 같은 텍스트"), "MYPROJ-12")
    }

    // MARK: allMatches

    func test_allMatches_여러개() {
        XCTAssertEqual(
            sut.allMatches(in: "PROJ-1 ABC-22 XYZ-333"),
            ["PROJ-1", "ABC-22", "XYZ-333"]
        )
    }

    func test_allMatches_없음() {
        XCTAssertEqual(sut.allMatches(in: "no match here"), [])
    }

    func test_allMatches_혼재() {
        // 잘못된 형식(소문자/숫자시작)은 제외.
        XCTAssertEqual(
            sut.allMatches(in: "PROJ-1 proj-2 123-4 XYZ-5"),
            ["PROJ-1", "XYZ-5"]
        )
    }
}
