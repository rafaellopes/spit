import Foundation
import Combine

// MARK: - LicenseManager
// Gestão de licenças Spit: trial, pro ($4.99/mês), byok ($49 único).
// Toda a comunicação de transcrição passa pelo proxy (exceto BYOK puro).
// Política: 1 dispositivo por licença — ativar noutro revoga o anterior.

enum SpitPlan: String, Codable {
    case trial  // 60 min grátis via proxy
    case pro    // $4.99/mês — 20h/mês via proxy
    case byok   // $49 único — chave OpenAI própria, sem proxy
}

enum LicenseError: LocalizedError {
    case noLicense
    case trialExhausted
    case monthlyLimitReached
    case deviceMismatch
    case invalidToken
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noLicense:           return "No active license."
        case .trialExhausted:      return "Free trial exhausted. Upgrade to continue."
        case .monthlyLimitReached: return "Monthly usage limit reached."
        case .deviceMismatch:      return "License activated on another device."
        case .invalidToken:        return "Invalid or expired activation link."
        case .networkError:        return "Network error. Check your connection."
        case .serverError(let m):  return m
        }
    }
}

class LicenseManager: ObservableObject {

    static let shared = LicenseManager()

    // MARK: - Published state

    @Published private(set) var plan: SpitPlan = .trial
    @Published private(set) var isActivated: Bool = false
    @Published private(set) var trialSecondsUsed: Double = 0
    @Published private(set) var monthlySecondsUsed: Double = 0
    @Published private(set) var userEmail: String? = nil

    let trialLimitSeconds: Double = 3600    // 60 min
    let proLimitSeconds: Double   = 72000   // 20h

    var trialExhausted: Bool { plan == .trial && trialSecondsUsed >= trialLimitSeconds }
    var trialMinutesRemaining: Int { max(0, Int((trialLimitSeconds - trialSecondsUsed) / 60)) }

    // MARK: - API base URL

    static let apiBase = "https://spit-api.rafa-782.workers.dev"

    // MARK: - Init

    private init() {
        loadLocalState()
        // Refresh status from server on startup (non-blocking)
        if isActivated {
            Task { await refreshStatus() }
        }
    }

    // MARK: - Trial usage (local, also validated server-side)

    func recordTrialUsage(seconds: Double) {
        guard plan == .trial else { return }
        trialSecondsUsed = min(trialLimitSeconds, trialSecondsUsed + seconds)
        UserDefaults.standard.set(trialSecondsUsed, forKey: "spit.trialSecondsUsed")
    }

    // MARK: - Activate from deep link  spit://activate?token=xxx&device_id=yyy

    func activate(token: String) async throws {
        let deviceId  = deviceIdentifier()
        let deviceName = Host.current().localizedName ?? "Mac"

        var req = URLRequest(url: URL(string: "\(Self.apiBase)/activate")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "token":       token,
            "device_id":   deviceId,
            "device_name": deviceName,
        ])
        req.timeoutInterval = 20

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw LicenseError.networkError }

        switch http.statusCode {
        case 200:
            let obj = try JSONDecoder().decode(ActivateResponse.self, from: data)
            await MainActor.run {
                saveJWT(obj.jwt)
                plan        = SpitPlan(rawValue: obj.plan) ?? .pro
                isActivated = true
            }
            saveLocalPlan(obj.plan)
        case 403: throw LicenseError.invalidToken
        default:
            let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error ?? "Server error"
            throw LicenseError.serverError(msg)
        }
    }

    // MARK: - Refresh status (JWT refresh + usage sync)

    @discardableResult
    func refreshStatus() async -> Bool {
        guard let jwt = getJWT() else { return false }

        var req = URLRequest(url: URL(string: "\(Self.apiBase)/license/status")!)
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              http.statusCode == 200,
              let obj = try? JSONDecoder().decode(LicenseStatusResponse.self, from: data)
        else { return false }

        await MainActor.run {
            plan                 = SpitPlan(rawValue: obj.plan) ?? plan
            trialSecondsUsed     = obj.trial_seconds_used ?? trialSecondsUsed
            monthlySecondsUsed   = obj.monthly_seconds_used ?? monthlySecondsUsed
            isActivated          = obj.device_matches
        }
        return true
    }

    // MARK: - Deactivate (uninstall / switch device)

    func deactivate() async {
        guard let jwt = getJWT() else { return }
        var req = URLRequest(url: URL(string: "\(Self.apiBase)/license/deactivate")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
        await MainActor.run { clearLocalState() }
    }

    // MARK: - JWT helpers (Keychain)

    func getJWT() -> String? {
        KeychainManager.shared.getString(account: "spit-jwt")
    }

    private func saveJWT(_ jwt: String) {
        KeychainManager.shared.saveString(jwt, account: "spit-jwt")
    }

    // MARK: - Device fingerprint

    func deviceIdentifier() -> String {
        // Stable per-machine identifier using IOPlatformUUID (hardware UUID)
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments  = ["-rd1", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Extract IOPlatformUUID value
        if let range = output.range(of: #""IOPlatformUUID" = "(.+?)""#, options: .regularExpression) {
            let match = output[range]
            let uuid = match.components(separatedBy: "\"")[3]
            return uuid
        }
        // Fallback: use a UUID stored in UserDefaults
        if let stored = UserDefaults.standard.string(forKey: "spit.deviceId") { return stored }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "spit.deviceId")
        return new
    }

    // MARK: - Persistence

    private func loadLocalState() {
        let planRaw = UserDefaults.standard.string(forKey: "spit.plan") ?? "trial"
        plan        = SpitPlan(rawValue: planRaw) ?? .trial
        isActivated = getJWT() != nil && plan != .trial
        trialSecondsUsed = UserDefaults.standard.double(forKey: "spit.trialSecondsUsed")
        userEmail   = UserDefaults.standard.string(forKey: "spit.userEmail")
    }

    private func saveLocalPlan(_ planRaw: String) {
        UserDefaults.standard.set(planRaw, forKey: "spit.plan")
    }

    private func clearLocalState() {
        KeychainManager.shared.deleteString(account: "spit-jwt")
        UserDefaults.standard.removeObject(forKey: "spit.plan")
        plan        = .trial
        isActivated = false
    }

    // MARK: - Response models

    private struct ActivateResponse: Codable {
        let jwt: String
        let plan: String
        let device_id: String
    }

    private struct LicenseStatusResponse: Codable {
        let plan: String
        let device_matches: Bool
        let trial_seconds_used: Double?
        let monthly_seconds_used: Double?
    }

    private struct APIError: Codable {
        let error: String
    }
}
