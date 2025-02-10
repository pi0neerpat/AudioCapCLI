import Foundation
import OSLog
import SwiftUI
import CoreAudio

let logger = Logger(subsystem: "com.example.AudioCap", category: "Main")
let kAppSubsystem = "com.example.AudioCap"

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

func listAvailableAudioProcesses() {
    let audioProcessController = AudioProcessController()
    audioProcessController.activate()
    let processes = audioProcessController.processes
    
    // Define a set of process names to exclude
    var excludedProcesses: Set<String> = [
        "PowerChime",
        "Terminal",
        "universalaccessd",
        "loginwindow",
        "Control Center",
        "Accessibility Services"
    ]
    
    // Get the current process name and add it to the excluded list
    let currentProcessName = ProcessInfo.processInfo.processName
    excludedProcesses.insert(currentProcessName)
    
    // Filter the processes
    let filteredProcesses = processes.filter { !excludedProcesses.contains($0.name) }
    
    if filteredProcesses.isEmpty {
        let message = "No audio processes available."
        logger.info("\(message)")
    } else {
        let message = "Available audio processes:"
        logger.info("\(message)")
        for process in filteredProcesses {
            let iconBase64 = convertIconToBase64(process.icon)
            let format = formatDescription(process.streamDescription)
            let message = ("\(process.name)|\(format)|\(iconBase64 ?? "No Icon")")
            logger.info("\(process.name)|\(format), privacy: .public)")
//            print(message)

        }
    }
}

func startRecording(sourceName: String) {
    logger.debug("Starting audio recording...")
    let audioProcessController = AudioProcessController()
    audioProcessController.activate()

    guard let process = audioProcessController.processes.first(where: { $0.name.contains(sourceName) }) else {
        logger.error("No audio processes available.")
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

    for argument in arguments {
        if argument.hasPrefix("--") {
            currentKey = String(argument.dropFirst(2))
            argumentDict[currentKey!] = nil // Initialize key with nil value
        } else if let key = currentKey {
            argumentDict[key] = argument
            currentKey = nil
        }
    }

    return argumentDict
}

let argumentDict = parseArguments(CommandLine.arguments)

let shouldListProcesses = argumentDict.keys.contains("list-sources")
let sourceName = argumentDict["source"] ?? nil

logger.debug("\(String(sourceName ?? "No source name provided."))")

Task { @MainActor in
    logger.debug("Initializing audio controllers...")
    let audioRecordingPermission = AudioRecordingPermission()

    logger.debug("Requesting audio recording permission...")
    await audioRecordingPermission.requestAndWait()

    if audioRecordingPermission.status == .authorized {
        logger.debug("Audio recording permission granted.")

        if shouldListProcesses {
            listAvailableAudioProcesses()
            exit(0)
        } else if (sourceName != nil) {
            startRecording(sourceName: String(sourceName ?? ""))
        } else {
            logger.error("No source name provided.")
            exit(1)
        }
    } else {
        logger.debug("Audio recording permission denied.")
        exit(1)
    }
}

RunLoop.main.run()
