import Foundation
import OSLog
import Combine
import UserNotifications
import CoreAudio

fileprivate let logger = Logger(subsystem: "com.example.purerate", category: "LogMonitor")

class LogMonitor: ObservableObject {
    @Published var currentSampleRate: Double?
    @Published var activeDeviceName: String?
    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }
    
    struct DeviceOption: Hashable {
        let id: AudioDeviceID
        let name: String
    }
    
    @Published var availableDevices: [DeviceOption] = []
    @Published var targetDeviceID: AudioDeviceID? {
        didSet {
            if let id = targetDeviceID {
                UserDefaults.standard.set(Int(id), forKey: "targetDeviceID")
            } else {
                UserDefaults.standard.removeObject(forKey: "targetDeviceID")
            }
            updateCurrentState()
        }
    }
    
    private var timer: Timer?
    private let manager = AudioDeviceManager.shared
    private var lastObservedRate: Double?
    
    init() {
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        if UserDefaults.standard.object(forKey: "targetDeviceID") != nil {
            self.targetDeviceID = AudioDeviceID(UserDefaults.standard.integer(forKey: "targetDeviceID"))
        }
        
        refreshDeviceList()
        updateCurrentState()
        startMonitoring()
    }
    
    func refreshDeviceList() {
        let devices = manager.getAllOutputDevices()
        DispatchQueue.main.async {
            self.availableDevices = devices.map { DeviceOption(id: $0.0, name: $0.1) }
        }
    }
    
    func updateCurrentState() {
        guard let deviceID = targetDeviceID ?? manager.getDefaultOutputDevice() else { return }
        let rate = manager.getNominalSampleRate(deviceID: deviceID)
        let name = manager.getDeviceName(deviceID: deviceID)
        
        DispatchQueue.main.async {
            self.currentSampleRate = rate
            self.activeDeviceName = name
        }
    }
    
    func startMonitoring() {
        timer?.invalidate()
        // Poll every 2 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollLogs()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func pollLogs() {
        guard isEnabled else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let store = try OSLogStore.local()
                let position = store.position(timeIntervalSinceEnd: -3.0)
                let predicate = NSPredicate(format: "(subsystem == 'com.apple.Music' OR subsystem == 'com.apple.coremedia' OR subsystem == 'com.apple.coreaudio') AND process == 'Music'")
                let entries = try store.getEntries(with: [], at: position, matching: predicate)
                
                var newSampleRate: Double?
                
                for entry in entries {
                    let message = entry.composedMessage
                    
                    if message.contains("audioCapabilities:") {
                        if let range1 = message.range(of: "asbdSampleRate = "),
                           let range2 = message.range(of: " kHz", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound])
                            if let val = Double(valStr) {
                                newSampleRate = val * 1000.0
                            }
                        }
                    } else if message.contains("Creating AudioQueue") && message.contains("sampleRate:") {
                        if let range1 = message.range(of: "sampleRate:") {
                            let substring = message[range1.upperBound...]
                            if let endIdx = substring.firstIndex(of: " ") ?? substring.firstIndex(of: "\n") {
                                let valStr = String(substring[..<endIdx])
                                if let val = Double(valStr) {
                                    newSampleRate = val
                                }
                            } else {
                                let valStr = String(substring)
                                if let val = Double(valStr) {
                                    newSampleRate = val
                                }
                            }
                        }
                    } else if message.contains("ACAppleLosslessDecoder") && message.contains("Input format:") {
                        if let range1 = message.range(of: "ch, "),
                           let range2 = message.range(of: " Hz", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound])
                            if let val = Double(valStr) {
                                newSampleRate = val
                            }
                        }
                    }
                }
                
                if let targetRate = newSampleRate, targetRate != self.lastObservedRate {
                    self.lastObservedRate = targetRate
                    self.updateDeviceSampleRate(to: targetRate)
                }
            } catch {
                logger.error("Failed to read OSLog: \(error.localizedDescription)")
            }
        }
    }
    
    func updateDeviceSampleRate(to rate: Double) {
        guard let deviceID = targetDeviceID ?? manager.getDefaultOutputDevice() else { return }
        
        let currentRate = manager.getNominalSampleRate(deviceID: deviceID)
        let name = manager.getDeviceName(deviceID: deviceID)
        
        DispatchQueue.main.async {
            self.activeDeviceName = name
        }
        
        if currentRate != rate {
            logger.notice("Switching sample rate to \(rate) Hz from \(currentRate ?? .nan)")
            let success = manager.setNominalSampleRate(deviceID: deviceID, sampleRate: rate)
            if success {
                DispatchQueue.main.async {
                    self.currentSampleRate = rate
                }
                if self.notificationsEnabled {
                    let content = UNMutableNotificationContent()
                    content.title = "Sample Rate Changed"
                    content.body = String(format: "Switched to %.1f kHz", rate / 1000.0)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            } else {
                logger.error("Failed to switch sample rate.")
            }
        } else {
             DispatchQueue.main.async {
                 self.currentSampleRate = rate
             }
        }
    }
}
