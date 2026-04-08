import SwiftUI

// MARK: - MenuBarPopoverView
// Popover shown when clicking the menu bar icon.

struct MenuBarPopoverView: View {

    @EnvironmentObject var dictationController: DictationController
    @EnvironmentObject var creditsManager: CreditsManager
    @EnvironmentObject var vocabularyManager: VocabularyManager

    @State private var lastResultCopied: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            accessibilityWarningView   // banner vermelho quando AX não está concedida
            retryBannerView            // banner laranja quando a última transcrição falhou
            creditsView
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            Divider()
            freeTrialCTAView
            if let result = dictationController.lastResult {
                lastResultView(result: result)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Divider()
            }
            actionsView
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundColor(.accentColor)
            Text("Spit")
                .font(.headline)
            Spacer()
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Credits

    private var creditsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: key status + monthly cost
            HStack {
                Image(systemName: creditsManager.mode == .userKey ? "key.fill" : "clock")
                    .font(.caption)
                    .foregroundColor(creditsManager.freeTrialExhausted ? .red : .secondary)
                Text(creditsManager.statusMessage)
                    .font(.caption)
                    .foregroundColor(creditsManager.freeTrialExhausted ? .red : .secondary)
                Spacer()
                if creditsManager.mode == .userKey {
                    Text(creditsManager.estimatedMonthlyCostFormatted)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .help("Estimated Whisper API spend this month (USD · $0.006/min)")
                }
            }

            // Row 2: value summary — only shown when there's meaningful usage this month
            if creditsManager.mode == .userKey, monthlyWordCount >= 50 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.accentColor.opacity(0.8))
                    Text(valueSummary)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Value Summary helpers

    /// Word count from HistoryManager entries in the current calendar month
    private var monthlyWordCount: Int {
        let cal = Calendar.current
        let now = Date()
        return HistoryManager.shared.entries
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// "X words → ~Y min saved this month"  (assumes 40 WPM average typing speed)
    private var valueSummary: String {
        let words = monthlyWordCount
        let minutesSaved = max(1, Int(Double(words) / 40.0))
        let wordsFormatted = words >= 1000
            ? String(format: "%.1fk", Double(words) / 1000)
            : "\(words)"
        return String(
            format: String(localized: "%1$@ words → ~%2$d min saved this month"),
            wordsFormatted,
            minutesSaved
        )
    }

    // MARK: - Last Result

    private func lastResultView(result: DictationResult) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.correctedText, forType: .string)
            withAnimation(.easeInOut(duration: 0.15)) { lastResultCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.2)) { lastResultCopied = false }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Last dictation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if lastResultCopied {
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    } else {
                        HStack(spacing: 4) {
                            Text("\(Int(result.duration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .transition(.opacity)
                    }
                }
                Text(result.correctedText)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(lastResultCopied
                          ? Color.green.opacity(0.08)
                          : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(lastResultCopied
                                  ? Color.green.opacity(0.3)
                                  : Color.clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: lastResultCopied)
        }
        .buttonStyle(.plain)
        .help("Click to copy to clipboard")
    }

    // MARK: - Accessibility Warning

    @ViewBuilder
    private var accessibilityWarningView: some View {
        if !dictationController.isAccessibilityTrusted {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.lock.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("Accessibility permission required")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                }
                Text("Text won't be typed automatically. Grant access in System Settings → Privacy → Accessibility.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                } label: {
                    Text("Open Settings")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.85))

            Divider()
        }
    }

    // MARK: - Retry Banner

    @ViewBuilder
    private var retryBannerView: some View {
        if dictationController.pendingRetryURL != nil {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                    Text("Last transcription failed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                }
                HStack {
                    Text("The audio is saved for 10 minutes.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Button("Retry") {
                        dictationController.retryPendingDictation()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.85))

            Divider()
        }
    }

    // MARK: - Free Trial CTA

    @ViewBuilder
    private var freeTrialCTAView: some View {
        if creditsManager.freeTrialExhausted {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Free trial exhausted")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                Text("Add your OpenAI API key in Settings to continue.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings → API Key") {
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.openSettings()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            Divider()
        }
    }

    // MARK: - Actions

    private var actionsView: some View {
        HStack {
            Button {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.openSettings()
                }
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Spit")
        }
    }

    // MARK: - State colour

    private var stateColor: Color {
        switch dictationController.state {
        case .idle:       return .green
        case .recording:  return .red
        case .processing: return .orange
        case .injecting:  return .blue
        case .error:      return .red
        }
    }
}

// MARK: - AudioLevelView

struct AudioLevelView: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(index: i))
                    .frame(width: 4, height: barHeight(index: i))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }

    private func normalizedLevel() -> Float {
        let clamped = max(-60, min(0, level))
        return (clamped + 60) / 60
    }

    private func barHeight(index: Int) -> CGFloat {
        let nl = normalizedLevel()
        let threshold = Float(index) / Float(barCount)
        return nl > threshold ? CGFloat(4 + index * 3) : 4
    }

    private func barColor(index: Int) -> Color {
        let nl = normalizedLevel()
        let threshold = Float(index) / Float(barCount)
        return nl > threshold ? .red : Color.secondary.opacity(0.3)
    }
}
