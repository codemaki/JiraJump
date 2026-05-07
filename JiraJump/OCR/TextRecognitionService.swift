import CoreGraphics
import Vision

// MARK: - 프로토콜
/// 이미지에서 텍스트를 추출하는 서비스.
protocol TextRecognitionServicing {
    /// 주어진 이미지에서 텍스트를 인식해 단일 문자열로 반환.
    /// 인식 영역은 공백으로 구분되어 join된다.
    /// - Parameters:
    ///   - image: 원본 CGImage.
    ///   - languages: 인식 언어 코드. 예: `["en-US"]`, `["en-US", "ko-KR"]`.
    func recognize(image: CGImage, languages: [String]) async throws -> String
}

// MARK: - Vision 구현
/// Apple `Vision` 프레임워크 기반 OCR.
/// `accurate` 레벨을 사용하고, 자연어 보정은 끈다 (Jira 키 같은 비자연어에 부적절).
final class VisionTextRecognitionService: TextRecognitionServicing {

    func recognize(image: CGImage, languages: [String]) async throws -> String {
        // Vision 호출은 CPU/GPU 집약 작업이므로 메인 스레드를 막지 않도록 detached Task에서 수행.
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            // 각 영역에서 최상위 후보 1개만 채택 후 공백 join.
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        }.value
    }
}
