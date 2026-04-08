import Foundation
import Security

// MARK: - KeychainManager
// Guarda a API key do utilizador de forma segura no Keychain do macOS.

class KeychainManager {

    static let shared = KeychainManager()
    private let service = "com.rafaellopes.voiceflow"
    private let apiKeyAccount = "openai-api-key"
    private let groqKeyAccount = "groq-api-key"

    private init() {}

    // MARK: - Guardar API Key

    func saveAPIKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount,
            kSecValueData:   data
        ]

        // Apagar entrada existente antes de criar nova
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Obter API Key

    func getAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      apiKeyAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    // MARK: - Apagar API Key

    func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: apiKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Verificar se existe

    var hasAPIKey: Bool {
        return getAPIKey() != nil
    }

    // MARK: - Groq API Key

    func saveGroqKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: groqKeyAccount,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func getGroqKey() -> String? { getString(account: groqKeyAccount) }
    func deleteGroqKey() { deleteString(account: groqKeyAccount) }
    var hasGroqKey: Bool { getGroqKey() != nil }

    // MARK: - Key para provider genérico

    func getKey(for provider: BYOKProvider) -> String? {
        switch provider {
        case .openai: return getAPIKey()
        case .groq:   return getGroqKey()
        }
    }

    func hasKey(for provider: BYOKProvider) -> Bool {
        getKey(for: provider) != nil
    }

    // MARK: - Generic string storage (used by LicenseManager for JWT, etc.)

    func saveString(_ value: String, account: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getString(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteString(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
