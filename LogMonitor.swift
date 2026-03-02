import Foundation
import OSLog
import Combine
import UserNotifications
import CoreAudio

fileprivate let logger = Logger(subsystem: "com.example.purerate", category: "LogMonitor")

// MARK: – Rate-Change History

/// A single recorded sample-rate switch event.
struct RateChangeEvent: Identifiable {
    let id = UUID()
    let date: Date
    let fromRate: Double?
    let toRate: Double
    let fromBitDepth: UInt32?
    let toBitDepth: UInt32?
    let deviceName: String?
    let success: Bool
}

// MARK: – LogMonitor

class LogMonitor: ObservableObject {
    // Current state
    @Published var currentSampleRate: Double?
    @Published var activeDeviceName: String?
    @Published var bitDepth: UInt32?
    @Published var supportedRates: [Double] = []
    @Published var isMonitoringActive: Bool = false   // visual heartbeat

    // Settings
    @Published var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
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

    // History
    @Published var rateChangeHistory: [RateChangeEvent] = []
    private let maxHistoryCount = 30

    // Devices
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

    // Errors surface
    @Published var lastError: String?

    // Internals
    private var timer: Timer?
    private let manager = AudioDeviceManager.shared
    private var lastObservedRate: Double?
    private var lastObservedBitDepth: UInt32?
    private var switchCount: Int = 0
    @Published var totalSwitches: Int = 0

    init() {
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        if UserDefaults.standard.object(forKey: "isEnabled") != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: "isEnabled")
        }
        if UserDefaults.standard.object(forKey: "targetDeviceID") != nil {
            self.targetDeviceID = AudioDeviceID(UserDefaults.standard.integer(forKey: "targetDeviceID"))
        }

        refreshDeviceList()
        updateCurrentState()
        if isEnabled {
            startMonitoring()
        }
    }

    // MARK: Devices

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
        let depth = manager.getStreamBitDepth(deviceID: deviceID)
        let rates = manager.getSupportedSampleRates(deviceID: deviceID)

        DispatchQueue.main.async {
            self.currentSampleRate = rate
            self.activeDeviceName = name
            self.bitDepth = depth
            self.supportedRates = rates
        }
    }

    // MARK: Monitoring

    func startMonitoring() {
        timer?.invalidate()
        DispatchQueue.main.async { self.isMonitoringActive = true }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollLogs()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async { self.isMonitoringActive = false }
    }

    // MARK: Log Parsing

    func pollLogs() {
        guard isEnabled else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let store = try OSLogStore.local()
                let position = store.position(timeIntervalSinceEnd: -3.0)

                // Broader predicate – also catches HAL & codec subsystems
                let predicate = NSPredicate(format:
                    "(subsystem == 'com.apple.Music' " +
                    "OR subsystem == 'com.apple.coremedia' " +
                    "OR subsystem == 'com.apple.coreaudio' " +
                    "OR subsystem BEGINSWITH 'com.apple.audio') " +
                    "AND process == 'Music'"
                )
                let entries = try store.getEntries(with: [], at: position, matching: predicate)

                var newSampleRate: Double?

                for entry in entries {
                    let message = entry.composedMessage

                    // Pattern 1: audioCapabilities: … asbdSampleRate = XX kHz
                    if message.contains("audioCapabilities:") {
                        if let range1 = message.range(of: "asbdSampleRate = "),
                           let range2 = message.range(of: " kHz", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                            if let val = Double(valStr) {
                                newSampleRate = val * 1000.0
                            }
                        }
                    }

                    // Pattern 2: Creating AudioQueue … sampleRate:XXXXX
                    else if message.contains("Creating AudioQueue") && message.contains("sampleRate:") {
                        if let range1 = message.range(of: "sampleRate:") {
                            let substring = message[range1.upperBound...]
                                .trimmingCharacters(in: .whitespaces)
                            let valStr: String
                            if let endIdx = substring.firstIndex(where: { $0 == " " || $0 == "\n" || $0 == "," }) {
                                valStr = String(substring[..<endIdx])
                            } else {
                                valStr = substring
                            }
                            if let val = Double(valStr) {
                                newSampleRate = val
                            }
                        }
                    }

                    // Pattern 3: ACAppleLosslessDecoder … Input format: … ch, XXXXX Hz
                    else if message.contains("ACAppleLosslessDecoder") && message.contains("Input format:") {
                        if let range1 = message.range(of: "ch, "),
                           let range2 = message.range(of: " Hz", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                            if let val = Double(valStr) {
                                newSampleRate = val
                            }
                        }
                    }

                    // Pattern 4: FLAC / AAC decoder format logs: sampleRate: XXXXX.0
                    else if (message.contains("FLACDecoder") || message.contains("AACDecoder"))
                              && message.contains("sampleRate:") {
                        if let range1 = message.range(of: "sampleRate:") {
                            let substring = message[range1.upperBound...]
                                .trimmingCharacters(in: .whitespaces)
                            let valStr: String
                            if let endIdx = substring.firstIndex(where: { $0 == " " || $0 == "\n" || $0 == "," }) {
                                valStr = String(substring[..<endIdx])
                            } else {
                                valStr = substring
                            }
                            if let val = Double(valStr), val > 1000 {
                                newSampleRate = val
                            }
                        }
                    }

                    // Pattern 5: outputSettings … sampleRate = XXXXX
                    else if message.contains("outputSettings") && message.contains("sampleRate =") {
                        if let range1 = message.range(of: "sampleRate =") {
                            let substring = message[range1.upperBound...]
                                .trimmingCharacters(in: .whitespaces)
                            let valStr: String
                            if let endIdx = substring.firstIndex(where: { $0 == " " || $0 == "\n" || $0 == "," || $0 == ";" }) {
                                valStr = String(substring[..<endIdx])
                            } else {
                                valStr = substring
                            }
                            if let val = Double(valStr), val > 1000 {
                                newSampleRate = val
                            }
                        }
                    }

                    // Extract Bit Depth from various patterns
                    var parsedBitDepth: UInt32? = nil
                    
                    if message.contains("[BitDepth ") {
                        if let range1 = message.range(of: "[BitDepth "),
                           let range2 = message.range(of: "]", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound]).trimmingCharacters(in: .whitespaces)
                            if let val = UInt32(valStr) { parsedBitDepth = val }
                        }
                    } else if message.contains("sdBitDepth = ") {
                        if let range1 = message.range(of: "sdBitDepth = "),
                           let range2 = message.range(of: " bit", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound]).trimmingCharacters(in: .whitespaces)
                            if let val = UInt32(valStr) { parsedBitDepth = val }
                        }
                    } else if message.contains("from ") && message.contains("-bit source") {
                        if let range1 = message.range(of: "from "),
                           let range2 = message.range(of: "-bit source", range: range1.upperBound..<message.endIndex) {
                            let valStr = String(message[range1.upperBound..<range2.lowerBound]).trimmingCharacters(in: .whitespaces)
                            if let val = UInt32(valStr) { parsedBitDepth = val }
                        }
                    }
                    
                    if let newDepth = parsedBitDepth {
                        // Only capture realistically valid bit depths (16, 24, 32)
                        if newDepth == 16 || newDepth == 24 || newDepth == 32 {
                            // If we already have a bit depth, don't overwrite it if it's the same, 
                            // but we'll collect the last valid one in the loop.
                            lastObservedBitDepth = newDepth
                        }
                    }
                }

                let targetBitDepth = self.lastObservedBitDepth
                
                if let targetRate = newSampleRate {
                    let rateChanged = targetRate != self.lastObservedRate
                    // To handle the case where only bit depth changed but not sample rate
                    // We need the bit depth from the device to know if it actually needs changing
                    var bitDepthNeedsUpdate = false
                    
                    if let targetDepth = targetBitDepth {
                        let currentDeviceDepth = self.manager.getStreamBitDepth(deviceID: self.targetDeviceID ?? self.manager.getDefaultOutputDevice() ?? 0)
                        if currentDeviceDepth != targetDepth {
                            bitDepthNeedsUpdate = true
                        }
                    }

                    if rateChanged || bitDepthNeedsUpdate {
                        self.lastObservedRate = targetRate
                        self.updateDeviceSampleRate(to: targetRate, targetBitDepth: targetBitDepth)
                    }
                }

                DispatchQueue.main.async {
                    self.lastError = nil
                    // Ensure the UI bit depth stays in sync with the last valid observed bit depth
                    if let observedDepth = self.lastObservedBitDepth {
                        self.bitDepth = observedDepth
                    }
                }
            } catch {
                logger.error("Failed to read OSLog: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    // MARK: Rate Switching

    func updateDeviceSampleRate(to rate: Double, targetBitDepth: UInt32?) {
        guard let deviceID = targetDeviceID ?? manager.getDefaultOutputDevice() else { return }

        let currentRate = manager.getNominalSampleRate(deviceID: deviceID)
        let currentDepth = manager.getStreamBitDepth(deviceID: deviceID)
        let name = manager.getDeviceName(deviceID: deviceID)

        DispatchQueue.main.async {
            self.activeDeviceName = name
        }

        if currentRate != rate || (targetBitDepth != nil && currentDepth != targetBitDepth) {
            logger.notice("Switching sample rate to \(rate) Hz from \(currentRate ?? .nan) and bit depth to \(targetBitDepth ?? 0)")
            let success = manager.setDeviceFormat(deviceID: deviceID, sampleRate: rate, bitDepth: targetBitDepth)

            let event = RateChangeEvent(
                date: Date(),
                fromRate: currentRate,
                toRate: rate,
                fromBitDepth: currentDepth,
                toBitDepth: targetBitDepth,
                deviceName: name,
                success: success
            )

            if success {
                DispatchQueue.main.async {
                    self.currentSampleRate = rate
                    self.bitDepth = self.manager.getStreamBitDepth(deviceID: deviceID)
                    self.totalSwitches += 1
                    self.rateChangeHistory.insert(event, at: 0)
                    if self.rateChangeHistory.count > self.maxHistoryCount {
                        self.rateChangeHistory.removeLast()
                    }
                }

                if self.notificationsEnabled {
                    let content = UNMutableNotificationContent()
                    content.title = "PureRate"
                    let bitDepthString = targetBitDepth != nil ? ", \(targetBitDepth!)-bit" : ""
                    content.body = String(format: "Switched to %.1f kHz%@ on %@", rate / 1000.0, bitDepthString, name ?? "device")
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request)
                }
            } else {
                logger.error("Failed to switch sample rate to \(rate) Hz.")
                DispatchQueue.main.async {
                    self.lastError = String(format: "Failed to set %.1f kHz", rate / 1000.0)
                    self.rateChangeHistory.insert(event, at: 0)
                    if self.rateChangeHistory.count > self.maxHistoryCount {
                        self.rateChangeHistory.removeLast()
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                self.currentSampleRate = rate
            }
        }
    }
}
