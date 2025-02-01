import Foundation
import OSLog
import SwiftUI

let logger = Logger(subsystem: "com.example.AudioCap", category: "Main")
let kAppSubsystem = "com.example.AudioCap"

func convertIconToBase64(_ icon: NSImage) -> String? {
    guard let tiffData = icon.tiffRepresentation else { return nil }
    guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
    
    return pngData.base64EncodedString() // No options for no line breaks
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
            logger.info("\(process.name)")
            let iconBase64 = convertIconToBase64(process.icon)
            print("\(process.name)|\(iconBase64 ?? "No Icon")")
        }
    }
}

func startRecording() {
    logger.debug("Starting audio recording...")
    let audioProcessController = AudioProcessController()
    audioProcessController.activate()

    guard let process = audioProcessController.processes.first(where: { $0.name.contains("Spotify") }) else {
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

// Check for the presence of the "--list-processes" flag
let shouldListProcesses = CommandLine.arguments.contains("--list-sources")

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
        } else {
           startRecording()
        }
    } else {
        logger.debug("Audio recording permission denied.")
        exit(1)
    }
}

RunLoop.main.run()
