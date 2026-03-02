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

    func setDeviceFormat(deviceID: AudioDeviceID, sampleRate: Double, bitDepth: UInt32? = nil) -> Bool {
        // 1. Get the first output stream
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { return false }

        let streamCount = Int(dataSize) / MemoryLayout<AudioStreamID>.size
        var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
        status = AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &dataSize, &streamIDs)
        if status != noErr || streamIDs.isEmpty { return false }

        let streamID = streamIDs[0]

        // 1.5 Get current physical format to ensure we maintain the same channel count
        var currentFormatAddress = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyPhysicalFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var currentFormat = AudioStreamBasicDescription()
        dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let currentStatus = AudioObjectGetPropertyData(streamID, &currentFormatAddress, 0, nil, &dataSize, &currentFormat)
        
        // Default to stereo if we can't get it, otherwise use whatever the stream is already set to
        let currentChannels: UInt32 = (currentStatus == noErr && currentFormat.mChannelsPerFrame > 0) ? currentFormat.mChannelsPerFrame : 2

        // 2. Get available physical formats for the stream
        var availFormatsAddress = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(streamID, &availFormatsAddress, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { return false }

        let formatCount = Int(dataSize) / MemoryLayout<AudioStreamRangedDescription>.size
        var availableFormats = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: formatCount)
        status = AudioObjectGetPropertyData(streamID, &availFormatsAddress, 0, nil, &dataSize, &availableFormats)
        if status != noErr || availableFormats.isEmpty { return false }

        // 3. Strict format matching
        var matchingFormats: [AudioStreamBasicDescription] = []

        for rangedDesc in availableFormats {
            let asbd = rangedDesc.mFormat
            if asbd.mFormatID != kAudioFormatLinearPCM { continue }
            // 3.1 channels must match current active channels to avert routing resets
            if asbd.mChannelsPerFrame != currentChannels { continue }

            let isDiscrete = (rangedDesc.mSampleRateRange.mMinimum == rangedDesc.mSampleRateRange.mMaximum)
            var candidateRateMatched = false
            var candidateASBD = asbd

            // 3.2 Safe Rate Matching
            if isDiscrete {
                // For discrete formats, we CANNOT mutate mSampleRate, otherwise the device considers it an invalid format and shows 'null'
                if abs(asbd.mSampleRate - sampleRate) < 1.0 {
                    candidateRateMatched = true
                    // keep candidateASBD as is
                }
            } else {
                // For continuous range formats, we check if our rate is bounds, and if so, we safely mutate
                if sampleRate >= rangedDesc.mSampleRateRange.mMinimum && sampleRate <= rangedDesc.mSampleRateRange.mMaximum {
                    candidateRateMatched = true
                    candidateASBD.mSampleRate = sampleRate
                }
            }

            if candidateRateMatched {
                matchingFormats.append(candidateASBD)
            }
        }

        // 3.3 Find the absolute best format using a strict scoring algorithm
        let bestFormat = matchingFormats.max { (a, b) -> Bool in
            // Return true if `a` is strictly mathematically WORSE than `b`,
            // so `max` will pick the "best" one.

            // Priority 1: Exact Bit Depth Match
            if let target = bitDepth {
                let aExact = (a.mBitsPerChannel == target)
                let bExact = (b.mBitsPerChannel == target)
                if aExact != bExact {
                    return !aExact && bExact // a is worse if it's not exact but b is
                }
            }

            // Priority 2: Higher Bit Depth (if exact doesn't apply or both are exact)
            if a.mBitsPerChannel != b.mBitsPerChannel {
                return a.mBitsPerChannel < b.mBitsPerChannel // a is worse if smaller
            }

            // Priority 3: Exact Format Flags Match (Mixable vs Non-Mixable, Interleaved, etc.)
            // Crucial to prevent OS from rejecting the format and dropping the speaker routing
            let aFlagsMatch = (a.mFormatFlags == currentFormat.mFormatFlags)
            let bFlagsMatch = (b.mFormatFlags == currentFormat.mFormatFlags)
            if aFlagsMatch != bFlagsMatch {
                return !aFlagsMatch && bFlagsMatch // a is worse if it doesn't match current flags but b does
            }

            return false // They are equal in priority
        }

        // 4. Safely applying format
        var formatSetSuccess = false
        if var formatToSet = bestFormat {
            var physFormatAddr = AudioObjectPropertyAddress(
                mSelector: kAudioStreamPropertyPhysicalFormat,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            let physStatus = AudioObjectSetPropertyData(streamID, &physFormatAddr, 0, nil, asbdSize, &formatToSet)
            if physStatus == noErr {
                formatSetSuccess = true
            }
        }

        // 5. Fallback if format application failed or no suitable format was found
        if !formatSetSuccess {
            // Revert to simply changing the nominal sample rate. This is the minimum required capability.
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var targetSampleRate: Float64 = sampleRate
            status = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, UInt32(MemoryLayout<Float64>.size), &targetSampleRate)
            return status == noErr
        }

        return formatSetSuccess
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
