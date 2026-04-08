import Foundation
import Combine

// MARK: - CreditsManager
// Controla o acesso à API e o consumo de minutos do utilizador.
// Modelo: BYOK puro — utilizador usa a sua própria chave OpenAI.
// Free trial = primeiros 30 min com a chave do utilizador (contagem local).

enum APIKeyMode {
    case freeTrial      // Chave própria do utilizador, com contagem de 30 min grátis
    case userKey        // BYOK ilimitado (após confirmar intenção de uso contínuo)
}

class CreditsManager: ObservableObject {

    static let shared = CreditsManager()

    // MARK: - Estado

    @Published private(set) var minutesUsed: Double = 0
    @Published private(set) var mode: APIKeyMode = .freeTrial
    @Published private(set) var totalSecondsTranscribed: Double = 0   // lifetime total
    @Published private(set) var monthlySecondsTranscribed: Double = 0  // current month only

    let freeTrialMinutesTotal: Double = 60  // 60 min grátis

    /// Estimated Whisper cost for the current calendar month — $0.006 / min
    var estimatedMonthlyCost: Double {
        monthlySecondsTranscribed / 60.0 * 0.006
    }

    /// Compact display: "~$0.04 /mo" — always in USD so users worldwide understand the currency
    var estimatedMonthlyCostFormatted: String {
        let cost = estimatedMonthlyCost
        if cost < 0.0001 {
            return "~$0.00 /mo"
        } else if cost < 0.01 {
            return String(format: "~$%.4f /mo", cost)
        } else {
            return String(format: "~$%.2f /mo", cost)
        }
    }

    var freeTrialMinutesRemaining: Double {
        max(0, freeTrialMinutesTotal - minutesUsed)
    }

    var freeTrialExhausted: Bool {
        mode == .freeTrial && minutesUsed >= freeTrialMinutesTotal
    }

    var hasUserAPIKey: Bool {
        KeychainManager.shared.hasAPIKey
    }

    // MARK: - Chave a usar

    var activeAPIKey: String? {
        // Sempre usa a chave do utilizador — BYOK puro
        return KeychainManager.shared.getAPIKey()
    }

    private let minutesUsedKey    = "creditsMinutesUsed"
    private let modeKey           = "creditsMode"
    private let totalSecondsKey   = "creditsTotalSeconds"
    private let monthlySecondsKey = "creditsMonthlySeconds"
    private let monthlyPeriodKey  = "creditsMonthlyPeriod"   // stored as "YYYY-MM"

    private var currentMonthPeriod: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: Date())
    }

    private init() {
        minutesUsed = UserDefaults.standard.double(forKey: minutesUsedKey)
        totalSecondsTranscribed = UserDefaults.standard.double(forKey: totalSecondsKey)
        let savedMode = UserDefaults.standard.string(forKey: modeKey)
        mode = (savedMode == "userKey") ? .userKey : .freeTrial

        // Load monthly counter — reset if we've rolled into a new month
        let savedPeriod = UserDefaults.standard.string(forKey: monthlyPeriodKey) ?? ""
        if savedPeriod == currentMonthPeriod {
            monthlySecondsTranscribed = UserDefaults.standard.double(forKey: monthlySecondsKey)
        } else {
            monthlySecondsTranscribed = 0
            UserDefaults.standard.set(0, forKey: monthlySecondsKey)
            UserDefaults.standard.set(currentMonthPeriod, forKey: monthlyPeriodKey)
        }
        vfLog("CreditsManager.init() — mode: \(mode), minutesUsed: \(minutesUsed), monthly: \(monthlySecondsTranscribed)s")

        // Verificação de chave no Keychain feita de forma assíncrona
        // para evitar bloquear o init (Keychain pode pedir autorização)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            vfLog("CreditsManager — checking Keychain for user API key...")
            if self.hasUserAPIKey {
                self.mode = .userKey
                vfLog("CreditsManager — modo BYOK auto-activado (chave encontrada)")
            } else {
                vfLog("CreditsManager — sem chave no Keychain")
            }
        }
    }

    // MARK: - Registar Uso

    func registerUsage(seconds: TimeInterval) {
        // Lifetime total
        totalSecondsTranscribed += seconds
        UserDefaults.standard.set(totalSecondsTranscribed, forKey: totalSecondsKey)

        // Monthly total — reset if month rolled over
        let period = currentMonthPeriod
        if UserDefaults.standard.string(forKey: monthlyPeriodKey) != period {
            monthlySecondsTranscribed = 0
            UserDefaults.standard.set(period, forKey: monthlyPeriodKey)
        }
        monthlySecondsTranscribed += seconds
        UserDefaults.standard.set(monthlySecondsTranscribed, forKey: monthlySecondsKey)

        // Free trial counter
        guard mode == .freeTrial else { return }
        let minutes = seconds / 60.0
        minutesUsed += minutes
        UserDefaults.standard.set(minutesUsed, forKey: minutesUsedKey)
    }

    // MARK: - Activar BYOK

    func activateUserKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let saved = KeychainManager.shared.saveAPIKey(key)
        if saved {
            mode = .userKey
            UserDefaults.standard.set("userKey", forKey: modeKey)
            print("[CreditsManager] Modo BYOK activado")
        }
        return saved
    }

    // MARK: - Voltar para Free Trial (ex: remoção de chave)

    func removeUserKey() {
        KeychainManager.shared.deleteAPIKey()
        mode = .freeTrial
        UserDefaults.standard.set("freeTrial", forKey: modeKey)
    }

    // MARK: - Verificar se pode ditar

    func canDictate() -> Bool {
        guard hasUserAPIKey else { return false }
        switch mode {
        case .userKey:
            return true
        case .freeTrial:
            return !freeTrialExhausted
        }
    }

    // MARK: - Mensagem de estado para UI

    var statusMessage: String {
        switch mode {
        case .userKey:
            return String(localized: "Own key")
        case .freeTrial:
            if freeTrialExhausted {
                return String(localized: "Trial ended — add your key")
            }
            let remaining = Int(freeTrialMinutesRemaining)
            return String(format: String(localized: "%d min free left"), remaining)
        }
    }
}
