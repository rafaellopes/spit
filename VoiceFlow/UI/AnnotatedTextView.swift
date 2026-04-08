import SwiftUI
import AppKit

// MARK: - WordToken

struct WordToken: Identifiable {
    let id = UUID()
    let text: String         // display text (may include trailing punctuation)
    let clean: String        // text stripped of punctuation, for lookup
    let isSuspicious: Bool
}

// MARK: - Suspicious Word Detection
// Heuristic: flags words that Whisper commonly transcribes incorrectly.
// Rules:
//  1. Mid-sentence capitalisation (proper nouns, brand names)
//  2. All-caps acronyms (e.g. API, MEMSAGE)
//  3. CamelCase words (e.g. OpenAI, iPhone)
// Words shorter than 3 chars are ignored to reduce false positives.

func detectSuspiciousWords(in text: String) -> Set<String> {
    var suspicious = Set<String>()
    let rawWords  = text.components(separatedBy: .whitespaces)
    let sentenceEnders = CharacterSet(charactersIn: ".!?…")
    var afterSentenceEnd = true   // first word is always a sentence start

    for (i, raw) in rawWords.enumerated() {
        let clean = raw.trimmingCharacters(in: .punctuationCharacters)
        defer {
            // Track sentence boundaries
            if let last = raw.unicodeScalars.last, sentenceEnders.contains(last) {
                afterSentenceEnd = true
            } else {
                afterSentenceEnd = false
            }
        }

        guard clean.count >= 3, clean.rangeOfCharacter(from: .letters) != nil else { continue }

        let letters = clean.filter { $0.isLetter }

        // Rule 1: mid-sentence capital first letter
        if i > 0 && !afterSentenceEnd && clean.first?.isUppercase == true {
            suspicious.insert(clean)
        }

        // Rule 2: all-caps (e.g. API, UUID)
        if letters.count >= 2 && String(letters) == String(letters).uppercased() {
            suspicious.insert(clean)
        }

        // Rule 3: CamelCase — uppercase letter after the first character
        if clean.dropFirst().contains(where: { $0.isUppercase }) {
            suspicious.insert(clean)
        }
    }
    return suspicious
}

// MARK: - Tokeniser

func tokenise(_ text: String, suspicious: Set<String>) -> [WordToken] {
    let rawWords = text.components(separatedBy: .whitespaces)
    return rawWords.map { raw in
        let clean = raw.trimmingCharacters(in: .punctuationCharacters)
        let isSusp = clean.count >= 3 && suspicious.contains(clean)
        return WordToken(text: raw, clean: clean, isSuspicious: isSusp)
    }.filter { !$0.text.isEmpty }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var hSpacing: CGFloat = 4
    var vSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0.0) { sum, row in
            sum + (row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0) + vSpacing
        }
        return CGSize(
            width: proposal.width ?? 0,
            height: max(0, height - vSpacing)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + hSpacing
            }
            y += rowHeight + vSpacing
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = []
        var current: [LayoutSubview] = []
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let w = subview.sizeThatFits(.unspecified).width
            if rowWidth + w + hSpacing > maxWidth + 1 && !current.isEmpty {
                rows.append(current)
                current = [subview]
                rowWidth = w + hSpacing
            } else {
                current.append(subview)
                rowWidth += w + hSpacing
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - AnnotatedTextView

struct AnnotatedTextView: View {

    let tokens: [WordToken]
    /// Called when user applies a correction: (original clean word, replacement text, addToVocabulary)
    var onCorrect: ((String, String, Bool) -> Void)?

    @State private var selectedToken: WordToken? = nil
    @State private var replacement: String = ""
    @State private var addToVocabulary: Bool = true

    var body: some View {
        FlowLayout(hSpacing: 4, vSpacing: 6) {
            ForEach(tokens) { token in
                wordView(token)
            }
        }
    }

    // MARK: - Word View

    @ViewBuilder
    private func wordView(_ token: WordToken) -> some View {
        let isSelected = selectedToken?.id == token.id

        Group {
            if token.isSuspicious {
                // Red dotted underline via AttributedString
                Text(suspiciousAttr(token.text))
                    .font(.system(size: 14))
                    .foregroundColor(Color(nsColor: .labelColor))
            } else {
                Text(token.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
        }
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            replacement = token.clean.isEmpty ? token.text : token.clean
            selectedToken = token
        }
        .popover(isPresented: Binding(
            get: { selectedToken?.id == token.id },
            set: { if !$0 { selectedToken = nil } }
        ), arrowEdge: .bottom) {
            correctionPopover(for: token)
        }
    }

    // MARK: - Correction Popover

    private func correctionPopover(for token: WordToken) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Correct word")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    Text("Whisper wrote:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(token.clean.isEmpty ? token.text : token.clean)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
            }

            TextField("Correction…", text: $replacement)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit { applyCorrection(for: token) }

            Toggle("Save as substitution (future dictations)", isOn: $addToVocabulary)
                .font(.caption)
                .toggleStyle(.checkbox)

            HStack(spacing: 8) {
                Button("Apply") {
                    applyCorrection(for: token)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(replacement.trimmingCharacters(in: .whitespaces).isEmpty
                          || replacement == token.clean)

                Button("Cancel") { selectedToken = nil }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
    }

    // MARK: - Helpers

    private func applyCorrection(for token: WordToken) {
        let trimmed = replacement.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != token.clean else { return }
        onCorrect?(token.clean.isEmpty ? token.text : token.clean, trimmed, addToVocabulary)
        selectedToken = nil
    }

    private func suspiciousAttr(_ text: String) -> AttributedString {
        var attr = AttributedString(text)
        attr.underlineStyle = Text.LineStyle(pattern: .dot, color: .red)
        return attr
    }
}
