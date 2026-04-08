import Foundation
import Combine

// MARK: - DictationHistoryEntry

struct DictationHistoryEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var date: Date
    var duration: TimeInterval
    var wordCount: Int
}

// MARK: - HistoryManager
// Persists the last 50 transcriptions locally (UserDefaults).
// Used for recovery if injection fails or the user loses text.

class HistoryManager: ObservableObject {

    static let shared = HistoryManager()

    @Published private(set) var entries: [DictationHistoryEntry] = []

    private let maxEntries = 50
    private let storageKey = "dictationHistory"

    private init() {
        load()
    }

    func add(text: String, duration: TimeInterval) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        let entry = DictationHistoryEntry(
            text: text, date: Date(), duration: duration, wordCount: words)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        save()
    }

    func delete(_ entry: DictationHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([DictationHistoryEntry].self, from: data)
        else { return }
        entries = saved
    }
}
