import Foundation

// MARK: - ProxyTranscriptionService
// Sends audio to the Spit proxy (Cloudflare Worker → Groq Whisper).
// Used for trial and pro plans. BYOK uses WhisperService directly.

struct ProxyResult {
    let text: String
    let detectedLanguage: String?
    let seconds: Double
}

class ProxyTranscriptionService {

    private let baseURL = LicenseManager.apiBase

    func transcribe(
        audioURL: URL,
        language: String,
        vocabularyHint: String
    ) async throws -> ProxyResult {

        guard let jwt = LicenseManager.shared.getJWT() else {
            throw WhisperError.noAPIKey
        }

        let boundary = "Spit-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "\(baseURL)/transcribe")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180

        let audioData = try Data(contentsOf: audioURL)
        let crlf = "\r\n"
        var body = Data()

        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        field("language", language)
        if !vocabularyHint.isEmpty { field("prompt", vocabularyHint) }

        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed:
                throw WhisperError.noInternet
            case .timedOut: throw WhisperError.timeout
            default:        throw WhisperError.networkError(urlError)
            }
        }

        guard let http = response as? HTTPURLResponse else { throw WhisperError.invalidResponse }

        switch http.statusCode {
        case 200: break
        case 401: throw WhisperError.unauthorized
        case 402:
            // Trial exhausted or monthly limit — parse which
            let msg = (try? JSONDecoder().decode(ProxyAPIError.self, from: data))?.error ?? ""
            if msg.contains("trial") { throw LicenseError.trialExhausted }
            throw LicenseError.monthlyLimitReached
        case 403:
            let msg = (try? JSONDecoder().decode(ProxyAPIError.self, from: data))?.error ?? ""
            if msg.contains("device") { throw LicenseError.deviceMismatch }
            throw WhisperError.unauthorized
        default:
            let msg = (try? JSONDecoder().decode(ProxyAPIError.self, from: data))?.error ?? "HTTP \(http.statusCode)"
            throw WhisperError.apiError(msg)
        }

        try? FileManager.default.removeItem(at: audioURL)

        guard let result = try? JSONDecoder().decode(ProxyResponse.self, from: data) else {
            throw WhisperError.invalidResponse
        }

        return ProxyResult(
            text: result.text,
            detectedLanguage: result.detected_language,
            seconds: result.seconds
        )
    }

    private struct ProxyResponse: Codable {
        let text: String
        let detected_language: String?
        let seconds: Double
    }

    private struct ProxyAPIError: Codable {
        let error: String
    }
}
