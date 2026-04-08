import SwiftUI

// MARK: - RecordingHUDState

enum RecordingHUDState {
    case recording(words: String, startedAt: Date)   // mic active, rolling words
    case processing(startedAt: Date)                  // whisper is working
}

// MARK: - RecordingHUDView
// Small floating panel shown from recording start until the ReviewHUD appears.
// During recording: pulsing mic + last spoken words + elapsed time.
//   - After 45s: shows a "long dictation" warning.
// During processing: spinner + "Transcribing…" + elapsed time.

struct RecordingHUDView: View {

    let state: RecordingHUDState

    @State private var pulse = false
    @State private var elapsed: Int = 0

    private let longDictationThreshold = 120  // seconds (2 minutes)

    var body: some View {
        HStack(spacing: 10) {
            indicator
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.regularMaterial)
        )
        .onAppear {
            if case .recording = state { pulse = true }
            startTimer()
        }
        .onChange(of: isRecording) { recording in
            pulse = recording
        }
    }

    // MARK: - Indicator

    private var indicator: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .scaleEffect(pulse ? 1.25 : 1.0)
                .animation(
                    pulse ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )

            Image(systemName: indicatorIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(indicatorColor)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch state {
            case .recording(let words, _):
                HStack(spacing: 6) {
                    if words.isEmpty {
                        Text("Listening…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text("…\(words)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.primary.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.head)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .animation(.easeInOut(duration: 0.15), value: words)
                    }
                    Spacer(minLength: 0)
                    Text(timeString(elapsed))
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundColor(.secondary.opacity(0.7))
                }

                // Long dictation warning
                if elapsed >= longDictationThreshold {
                    Text("Long dictation — consider stopping and continuing in parts")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeIn(duration: 0.3), value: elapsed >= longDictationThreshold)
                }

            case .processing(_):
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .frame(width: 14, height: 14)
                    Text("Transcribing…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 0)
                    Text(timeString(elapsed))
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        let startedAt: Date
        switch state {
        case .recording(_, let t): startedAt = t
        case .processing(let t): startedAt = t
        }
        // Update elapsed every second using a recursive DispatchQueue call
        func tick() {
            elapsed = max(0, Int(Date().timeIntervalSince(startedAt)))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tick() }
        }
        tick()
    }

    // MARK: - Helpers

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private var indicatorColor: Color {
        switch state {
        case .recording: return .red
        case .processing: return .orange
        }
    }

    private var indicatorIcon: String {
        switch state {
        case .recording: return "mic.fill"
        case .processing: return "waveform"
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}
