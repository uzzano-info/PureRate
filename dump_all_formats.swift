import Foundation
import CoreAudio

func dumpAll() {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress, 0, nil, &dataSize
    )
    
    let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress, 0, nil, &dataSize, &deviceIDs
    )

    for deviceID in deviceIDs {
        // Output Streams
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { continue }
        
        let streamCount = Int(dataSize) / MemoryLayout<AudioStreamID>.size
        var streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
        AudioObjectGetPropertyData(deviceID, &streamAddress, 0, nil, &dataSize, &streamIDs)
        if streamIDs.isEmpty { continue }
        
        // Name
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &deviceName)
        
        print("==============================")
        print("Device: \(deviceName) (ID: \(deviceID))")
        
        let streamID = streamIDs[0]
        var availAddr = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyAvailablePhysicalFormats,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        status = AudioObjectGetPropertyDataSize(streamID, &availAddr, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { continue }
        
        let formatCount = Int(dataSize) / MemoryLayout<AudioStreamRangedDescription>.size
        var availableFormats = [AudioStreamRangedDescription](repeating: AudioStreamRangedDescription(), count: formatCount)
        AudioObjectGetPropertyData(streamID, &availAddr, 0, nil, &dataSize, &availableFormats)
        
        var currentFormatAddr = AudioObjectPropertyAddress(
            mSelector: kAudioStreamPropertyPhysicalFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var currentFormat = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        AudioObjectGetPropertyData(streamID, &currentFormatAddr, 0, nil, &asbdSize, &currentFormat)
        print("Current Format: mFormatFlags=\(currentFormat.mFormatFlags), mChannels=\(currentFormat.mChannelsPerFrame), mBits=\(currentFormat.mBitsPerChannel)")
        
        for (i, fmt) in availableFormats.enumerated() {
            let desc = fmt.mFormat
            print("[\(i)] Rate: \(fmt.mSampleRateRange.mMinimum) - \(fmt.mSampleRateRange.mMaximum) | Flags: \(desc.mFormatFlags) | Ch: \(desc.mChannelsPerFrame) | Bits: \(desc.mBitsPerChannel)")
        }
    }
}

dumpAll()
