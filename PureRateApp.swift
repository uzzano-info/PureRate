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
            HStack {
                Image(systemName: "waveform")
                if let rate = logMonitor.currentSampleRate {
                    Text(String(format: "%.1f kHz", rate / 1000.0))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    @EnvironmentObject var logMonitor: LogMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        VStack(spacing: 16) {
            Text("PureRate")
                .font(.headline)
            
            Toggle("Auto-Switching Enabled", isOn: $logMonitor.isEnabled)
                .toggleStyle(.switch)
            
            Toggle("Desktop Notifications", isOn: $logMonitor.notificationsEnabled)
                .toggleStyle(.switch)
            
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
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
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Target Device")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            }
            
            Divider()
            
            Button("Quit PureRate") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 250)
    }
}
