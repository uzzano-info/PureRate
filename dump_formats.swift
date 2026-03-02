import Foundation
import CoreAudio

func dumpFormats() {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = kAudioObjectUnknown
    var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

    var status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress, 0, nil, &dataSize, &deviceID
    )
    if status != noErr { print("Failed to get default device"); return }

    var nameAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceName: CFString = "" as CFString
    var nameSize = UInt32(MemoryLayout<CFString>.size)
    AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &deviceName)
    print("Device: \(deviceName)")

    var streamAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &dataSize)
    if status != noErr || dataSize == 0 { print("No streams"); return }

    let streamCount = Int(dataSize) / MemoryLayout<AudioStreamID>.size
    var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
    AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &dataSize, &streamIDs)
    let streamID = streamIDs[0]

    // Current Format
    var currentFormatAddr = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyPhysicalFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var currentFormat = AudioStreamBasicDescription()
    var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    AudioObjectGetPropertyData(streamID, &currentFormatAddr, 0, nil, &asbdSize, &currentFormat)
    print("\n--- Current Format ---")
    print(currentFormat)

    var availAddr = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    status = AudioObjectGetPropertyDataSize(streamID, &availAddr, 0, nil, &dataSize)
    if status != noErr || dataSize == 0 { print("No avail formats"); return }

    let formatCount = Int(dataSize) / MemoryLayout<AudioStreamRangedDescription>.size
    var availableFormats = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: formatCount)
    AudioObjectGetPropertyData(streamID, &availAddr, 0, nil, &dataSize, &availableFormats)

    print("\n--- Available Formats ---")
    for (i, fmt) in availableFormats.enumerated() {
        print("[\(i)] Rate Range: \(fmt.mSampleRateRange.mMinimum) - \(fmt.mSampleRateRange.mMaximum)")
        print("    Format: \(fmt.mFormat)")
    }
}

dumpFormats()
