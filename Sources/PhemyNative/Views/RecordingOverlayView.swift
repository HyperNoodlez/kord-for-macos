import SwiftUI

/// SwiftUI view displayed inside the recording overlay panel.
struct RecordingOverlayView: View {
    @ObservedObject var manager: RecordingManager
    @AppStorage("appTheme") private var appThemeKey = AppTheme.dark.rawValue

    private var overlayColorScheme: ColorScheme? {
        switch AppTheme(rawValue: appThemeKey) ?? .dark {
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var body: some View {
        Group {
            switch manager.phase {
            case .idle:
                EmptyView()
            case .recording:
                recordingPill
            case .processing:
                processingPill
            case .ready:
                resultCard
            case .error:
                errorCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(overlayColorScheme)
    }

    // MARK: - Recording State

    @AppStorage("accentColor") private var accentColorKey = AccentPreset.purple.rawValue

    private var accentColor: Color {
        (AccentPreset(rawValue: accentColorKey) ?? .purple).primary
    }

    private var recordingPill: some View {
        AudioRingView(level: manager.audioLevel, color: accentColor)
            .frame(width: 44, height: 44)
            .padding(10)
            .background(.thinMaterial.opacity(0.5), in: Circle())
            .overlay(Circle().stroke(.primary.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Processing State

    private var processingPill: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Processing...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.primary.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Result State

    private var resultCard: some View {
        let shape = RoundedRectangle(cornerRadius: 12)

        return VStack(alignment: .leading, spacing: 12) {
            if let llmError = manager.result?.llmError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11))
                    Text("LLM skipped: \(llmError)")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            ScrollView {
                Text(manager.result?.optimizedPrompt ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)

            HStack(spacing: 8) {
                overlayButton("Paste", systemImage: "doc.on.clipboard", primary: true) {
                    manager.paste()
                }
                overlayButton("Copy", systemImage: "doc.on.doc") {
                    manager.copy()
                }
                Spacer()
                overlayButton("Dismiss", systemImage: "xmark") {
                    manager.dismiss()
                }
            }

            if manager.accessibilityDenied {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 10))
                    Text("Keyboard shortcuts unavailable — grant Accessibility in System Settings")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Enter = Paste  |  Esc = Dismiss")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.stroke(.primary.opacity(0.15), lineWidth: 0.5))
        .frame(width: 380)
        .onKeyPress(.return) {
            manager.paste()
            return .handled
        }
        .onKeyPress(.escape) {
            manager.dismiss()
            return .handled
        }
    }

    // MARK: - Error State

    private var errorCard: some View {
        let shape = RoundedRectangle(cornerRadius: 12)

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(manager.errorMessage ?? "An error occurred")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }

            overlayButton("Dismiss", systemImage: "xmark") {
                manager.dismiss()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.stroke(.primary.opacity(0.15), lineWidth: 0.5))
        .onKeyPress(.escape) {
            manager.dismiss()
            return .handled
        }
    }

    // MARK: - Helpers

    private func overlayButton(
        _ title: String,
        systemImage: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(primary ? Color.accentColor : .primary.opacity(0.1))
        )
        .foregroundStyle(primary ? .white : .primary)
    }
}

// MARK: - Audio Ring View

/// An audio-reactive recording indicator with layered rings and glow.
/// Uses a power curve to exaggerate peaks for punchy visual response.
struct AudioRingView: View {
    var level: Float
    var color: Color

    /// Power-curved level for snappier visual peaks
    private var curved: CGFloat {
        let l = CGFloat(level)
        return pow(l, 0.6) // exaggerate mid-range, compress high
    }

    private var scale: CGFloat { 0.45 + 0.85 * curved }
    private var ringWidth: CGFloat { 3.5 + 3.0 * curved }
    private var glowRadius: CGFloat { 4 + 18 * curved }
    private var glowOpacity: CGFloat { 0.25 + 0.55 * curved }
    private var dotSize: CGFloat { 6 + 10 * curved }
    private var pulseScale: CGFloat { 1.0 + 0.6 * curved }

    var body: some View {
        ZStack {
            // Expanding pulse ring — fades out as it grows
            Circle()
                .stroke(color, lineWidth: 2)
                .scaleEffect(pulseScale)
                .opacity(Double(0.4 * (1.0 - curved)))

            // Soft outer glow
            Circle()
                .stroke(color, lineWidth: ringWidth * 0.7)
                .blur(radius: glowRadius)
                .opacity(glowOpacity)

            // Main ring stroke
            Circle()
                .stroke(color, lineWidth: ringWidth)
                .opacity(0.4 + 0.6 * curved)

            // Inner filled dot
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .opacity(0.5 + 0.5 * curved)
        }
        .scaleEffect(scale)
        .animation(.interpolatingSpring(stiffness: 280, damping: 18), value: level)
    }
}
