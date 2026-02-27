import SwiftUI
import ServiceManagement
import CoreAudio

@main
struct PureRateApp: App {
    @StateObject var logMonitor = LogMonitor()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(logMonitor)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: logMonitor.isEnabled ? "waveform" : "waveform.slash")
                if let rate = logMonitor.currentSampleRate {
                    Text(formatRateCompact(rate))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func formatRateCompact(_ rate: Double) -> String {
        let khz = rate / 1000.0
        if khz == khz.rounded() {
            return String(format: "%.0f kHz", khz)
        }
        return String(format: "%.1f kHz", khz)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var logMonitor: LogMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider().opacity(0.3)

            // Status Card
            statusCard
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Controls
            controlsSection
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Device Picker
            deviceSection
                .padding(.horizontal, 16)
                .padding(.top, 10)

            // Error Banner
            if let error = logMonitor.lastError {
                errorBanner(error)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Divider().opacity(0.3).padding(.top, 12)

            // History / Footer
            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
    }

    // MARK: – Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("PureRate")
                        .font(.system(size: 14, weight: .bold))
                    Text("Bit-Perfect Audio")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Live indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(logMonitor.isMonitoringActive && logMonitor.isEnabled ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
                    .shadow(color: logMonitor.isMonitoringActive && logMonitor.isEnabled ? Color.green.opacity(0.6) : .clear, radius: 3)
                Text(logMonitor.isEnabled ? "LIVE" : "OFF")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(logMonitor.isEnabled ? .green : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: – Status Card

    private var statusCard: some View {
        VStack(spacing: 10) {
            // Big sample rate display
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let rate = logMonitor.currentSampleRate {
                    let khz = rate / 1000.0
                    Text(formatRateDisplay(khz))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [sampleRateColor(rate), sampleRateColor(rate).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("kHz")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 2)
                } else {
                    Text("—")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Info chips
            HStack(spacing: 8) {
                if let name = logMonitor.activeDeviceName {
                    infoChip(icon: "hifispeaker", text: name)
                }

                if let depth = logMonitor.bitDepth, depth > 0 {
                    infoChip(icon: "square.stack.3d.up", text: "\(depth)-bit")
                }

                if let rate = logMonitor.currentSampleRate {
                    infoChip(
                        icon: rate > 48000 ? "star.fill" : "checkmark.circle",
                        text: rate > 48000 ? "Hi-Res" : "Lossless"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: – Controls

    private var controlsSection: some View {
        VStack(spacing: 8) {
            settingRow(icon: "bolt.fill", title: "Auto-Switching") {
                Toggle("", isOn: $logMonitor.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            settingRow(icon: "bell.fill", title: "Notifications") {
                Toggle("", isOn: $logMonitor.notificationsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            settingRow(icon: "sunrise", title: "Launch at Login") {
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update Launch at Login: \(error)")
                        }
                    }
            }
        }
    }

    // MARK: – Device Picker

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "hifispeaker.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Target Device")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    logMonitor.refreshDeviceList()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh device list")
            }

            Picker("", selection: $logMonitor.targetDeviceID) {
                Text("System Default").tag(AudioDeviceID?.none)
                ForEach(logMonitor.availableDevices, id: \.id) { device in
                    Text(device.name).tag(AudioDeviceID?(device.id))
                }
            }
            .labelsHidden()
            .onAppear {
                logMonitor.refreshDeviceList()
            }

            // Supported rates
            if !logMonitor.supportedRates.isEmpty {
                HStack(spacing: 4) {
                    Text("Supports:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(formatSupportedRates(logMonitor.supportedRates))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    // MARK: – Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.orange)
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: – Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            // History toggle
            if !logMonitor.rateChangeHistory.isEmpty {
                DisclosureGroup(isExpanded: $showHistory) {
                    VStack(spacing: 4) {
                        ForEach(logMonitor.rateChangeHistory.prefix(8)) { event in
                            historyRow(event)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                        Text("Recent Changes")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(logMonitor.totalSwitches) total")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Support Button
            Button {
                if let url = URL(string: "https://www.buymeachoffee.com/purerate") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.pink)
                    Text("Support PureRate")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.pink.opacity(0.1))
                )
            }
            .buttonStyle(.plain)

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit PureRate")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
    }

    // MARK: – Sub-components

    private func settingRow<C: View>(icon: String, title: String, @ViewBuilder control: () -> C) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12))
            Spacer()
            control()
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func historyRow(_ event: RateChangeEvent) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(event.success ? Color.green : Color.red)
                .frame(width: 5, height: 5)

            if let from = event.fromRate {
                Text(String(format: "%.1f", from / 1000.0))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Text(String(format: "%.1f kHz", event.toRate / 1000.0))
                .font(.system(size: 9, weight: .medium, design: .monospaced))

            Spacer()

            Text(event.date, style: .time)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    // MARK: – Helpers

    private func sampleRateColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<48001:   return .blue       // Standard Lossless
        case 48001..<96001: return .purple    // Hi-Res
        default:           return .pink       // Ultra Hi-Res
        }
    }

    private func formatRateDisplay(_ khz: Double) -> String {
        if khz == khz.rounded() {
            return String(format: "%.0f", khz)
        }
        return String(format: "%.1f", khz)
    }

    private func formatSupportedRates(_ rates: [Double]) -> String {
        let labels = rates.map { rate -> String in
            let khz = rate / 1000.0
            if khz == khz.rounded() {
                return String(format: "%.0f", khz)
            }
            return String(format: "%.1f", khz)
        }
        return labels.joined(separator: " · ")
    }
}
