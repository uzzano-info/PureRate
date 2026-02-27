import Foundation
import CoreAudio

/// Centralized manager for CoreAudio hardware interactions.
/// Provides device enumeration, sample rate query/set, and supported-rate discovery.
class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    // MARK: – Default Output

    func getDefaultOutputDevice() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    // MARK: – Device Enumeration

    func getAllOutputDevices() -> [(AudioDeviceID, String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        if status != noErr || dataSize == 0 { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        if status != noErr { return [] }

        var outputDevices: [(AudioDeviceID, String)] = []
        for deviceID in deviceIDs {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize)

            if streamSize > 0 {
                if let name = getDeviceName(deviceID: deviceID) {
                    outputDevices.append((deviceID, name))
                }
            }
        }

        return outputDevices
    }

    // MARK: – Device Name

    func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = withUnsafeMutablePointer(to: &deviceName) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &dataSize,
                ptr
            )
        }

        return status == noErr ? (deviceName as String) : nil
    }

    // MARK: – Sample Rate

    func getNominalSampleRate(deviceID: AudioDeviceID) -> Double? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 0.0
        var dataSize = UInt32(MemoryLayout<Float64>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &sampleRate
        )

        return status == noErr ? sampleRate : nil
    }

    func setNominalSampleRate(deviceID: AudioDeviceID, sampleRate: Double) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var targetSampleRate: Float64 = sampleRate
        let dataSize = UInt32(MemoryLayout<Float64>.size)

        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            dataSize,
            &targetSampleRate
        )

        return status == noErr
    }

    // MARK: – Supported Sample Rates

    /// Returns the list of nominal sample rates (Hz) a device declares it supports.
    func getSupportedSampleRates(deviceID: AudioDeviceID) -> [Double] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { return [] }

        let rangeCount = Int(dataSize) / MemoryLayout<AudioValueRange>.size
        var ranges = [AudioValueRange](repeating: AudioValueRange(), count: rangeCount)

        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &ranges)
        if status != noErr { return [] }

        // Each range has mMinimum and mMaximum.
        // For discrete rates they are equal.
        // For continuous ranges, we return the standard common rates that fall within.
        let commonRates: [Double] = [8000, 11025, 16000, 22050, 32000, 44100, 48000, 88200, 96000,
                                      176400, 192000, 352800, 384000, 705600, 768000]
        var supported: Set<Double> = []

        for range in ranges {
            if range.mMinimum == range.mMaximum {
                supported.insert(range.mMinimum)
            } else {
                for rate in commonRates where rate >= range.mMinimum && rate <= range.mMaximum {
                    supported.insert(rate)
                }
            }
        }

        return supported.sorted()
    }

    // MARK: – Bit Depth (best-effort)

    /// Returns the physical-format bit depth for the first output stream, if available.
    func getStreamBitDepth(deviceID: AudioDeviceID) -> UInt32? {
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { return nil }

        let streamCount = Int(dataSize) / MemoryLayout<AudioStreamID>.size
        var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
        status = AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &dataSize, &streamIDs)
        if status != noErr || streamIDs.isEmpty { return nil }

        let firstStream = streamIDs[0]

        var physFormatAddr = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyPhysicalFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var asbd = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioObjectGetPropertyData(firstStream, &physFormatAddr, 0, nil, &asbdSize, &asbd)
        if status != noErr { return nil }

        return asbd.mBitsPerChannel
    }
}
