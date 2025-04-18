import Foundation
import OSLog
import SwiftUI
import CoreAudio

let logger = Logger(subsystem: "com.example.AudioCap", category: "Main")
let kAppSubsystem = "com.example.AudioCap"

func printUsage() {
    print("""
    AudioCapCLI - Capture audio from applications
    
    Usage:
      AudioCapCLI --list-sources                List all available audio sources
      AudioCapCLI --source <name>               Record audio from specified source
    
    Examples:
      AudioCapCLI --list-sources
      AudioCapCLI --source Chrome
      AudioCapCLI --source "com.google.Chrome"
    """)
}

func convertIconToBase64(_ icon: NSImage) -> String? {
    guard let tiffData = icon.tiffRepresentation else { return nil }
    guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
    
    return pngData.base64EncodedString() // No options for no line breaks
}

func formatDescription(_ format: AudioStreamBasicDescription?) -> String {
    guard let format = format else { return "Unknown format" }
    return String(format: "%.0f Hz, %d ch", format.mSampleRate, format.mChannelsPerFrame)
}

@MainActor func getAvailableProcesses() -> [AudioProcess] {
    let audioProcessController = AudioProcessController()
    audioProcessController.activate()
    let processes = audioProcessController.processes
    
    // Process names to exclude
    var excludedProcessNames: Set<String> = [
        "universalaccessd",
        "Mail Graphics and Media",
        "Unknown",
        "(Plugin)"
    ]
    
    // Get the current process name and add it to the excluded list
    let currentProcessName = ProcessInfo.processInfo.processName
    excludedProcessNames.insert(currentProcessName)
    
    // Bundle IDs to exclude
    let excludedBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.loginwindow",
        "com.apple.PowerChime",
        "com.apple.Terminal",
        "com.apple.mail",
        "com.apple.accessibility.AXVisualSupportAgent",
        "com.apple.cloudpaird",
        "com.apple.AirPlayXPCHelper",
        "com.apple.avconferenced",
        "com.apple.audiomxd",
        "com.apple.cmio.ContinuityCaptureAgent",
        "com.apple.mediaanalysisd",
        "com.apple.mediaremoted",
        "systemsoundserverd",
        "com.apple.accessibility.heard",
        "com.apple.CoreSpeech",
        "com.apple.TelephonyUtilities"
    ]
    
    // Filter the processes
    return processes.filter { process in
        // Check if process name doesn't contain excluded substrings
        let nameNotExcluded = !excludedProcessNames.contains { excludedName in
            process.name == excludedName || // Exact match
            process.name.contains(excludedName) // Contains substring
        }
        
        // Check if bundle ID is not in the excluded list
        let bundleIDNotExcluded = process.bundleID.map { 
            !excludedBundleIDs.contains($0) 
        } ?? true // If bundleID is nil, consider it not excluded
        
        // Include only processes that pass both filters
        return nameNotExcluded && bundleIDNotExcluded
    }
}

@MainActor func listAvailableAudioProcesses() {
    let processes = getAvailableProcesses()
    
    if processes.isEmpty {
        let message = "No audio processes available."
        logger.info("\(message)")
    } else {
        let message = "Available audio processes:"
        logger.info("\(message)")
        for process in processes {
            let iconBase64 = convertIconToBase64(process.icon)
            let kind = process.kind.rawValue
            let audioActive = process.audioActive ? "Active" : "Inactive"
            let format = formatDescription(process.streamDescription)
            let message = ("\(process.name)|\(format)|\(iconBase64 ?? "No Icon")")
            logger.info("\(process.name)|\(format)|\(kind) \(audioActive)|\(process.bundleID ?? "no bundle ID")")
            print(message)
        }
    }
}

@MainActor func startRecording(sourceName: String) {
    logger.debug("Starting audio recording...")
    let processes = getAvailableProcesses()
    
    // Try to find a process by exact name match first
    var selectedProcess = processes.first(where: { $0.name == sourceName })
    
    // If no exact match, try partial name match
    if selectedProcess == nil {
        selectedProcess = processes.first(where: { $0.name.localizedCaseInsensitiveContains(sourceName) })
    }
    
    // If still no match, try by bundle ID
    if selectedProcess == nil {
        selectedProcess = processes.first(where: { 
            $0.bundleID?.localizedCaseInsensitiveContains(sourceName) == true 
        })
    }
    
    guard let process = selectedProcess else {
        logger.error("No matching audio process found for source: \(sourceName)")
        exit(1)
    }
    
    let tap = ProcessTap(process: process)
    let recorder = ProcessTapStandardOut(tap: tap)
    
    do {
        try recorder.start()
        _ = readLine()
    } catch {
        logger.error("Failed to start recording: \(error)")
        exit(1)
    }
}

func parseArguments(_ arguments: [String]) -> [String: String?] {
    var argumentDict = [String: String?]()
    var currentKey: String?
    
    let args = Array(arguments.dropFirst())
    
    for (index, argument) in args.enumerated() {
        if argument.hasPrefix("--") {
            let key = String(argument.dropFirst(2))
            
            // Check if this is the last argument or if the next argument is also a flag
            let isFlag = index == args.count - 1 || args[index + 1].hasPrefix("--")
            if isFlag {
                // For flags without values, we'll use an empty string to indicate presence
                argumentDict[key] = ""
                currentKey = nil
            } else {
                currentKey = key
            }
        } else if let key = currentKey {
            argumentDict[key] = argument
            currentKey = nil
        }
    }
    
    return argumentDict
}

Task { @MainActor in
    let argumentDict = parseArguments(CommandLine.arguments)
    
    // If no arguments, show usage
    if CommandLine.arguments.count == 1 {
        printUsage()
        exit(0)
    }
    
    let shouldListProcesses = argumentDict["list-sources"] != nil
    let sourceName = argumentDict["source"] ?? nil
    
    logger.debug("Initializing audio controllers...")
    let audioRecordingPermission = AudioRecordingPermission()

    logger.debug("Requesting audio recording permission...")
    await audioRecordingPermission.requestAndWait()

    if audioRecordingPermission.status == .authorized {
        logger.debug("Audio recording permission granted.")

        if shouldListProcesses {
            listAvailableAudioProcesses()
            exit(0)
        } else if let sourceName = sourceName {
            startRecording(sourceName: sourceName)
        } else {
            logger.error("No source name provided.")
            printUsage()
            exit(1)
        }
    } else {
        logger.debug("Audio recording permission denied.")
        exit(1)
    }
}

RunLoop.main.run()
