import Foundation
import OSLog

let logger = Logger(subsystem: "com.example.AudioCap", category: "Main")
let kAppSubsystem = "com.example.AudioCap"

func startRecording(audioProcessController: AudioProcessController) {
    guard let process = audioProcessController.processes.first(where: { $0.name.contains("Spotify") == true }) else {
        logger.error("No audio processes found.")
        exit(1)
    }

    let tap = ProcessTap(process: process)
    let recorder = ProcessTapRecorder(fileURL: URL(fileURLWithPath:"/Users/dev/Documents/recording.wav"), tap: tap)

    do {
        try recorder.start()
        print("Recording started. Press Enter to stop.")
        _ = readLine()
        recorder.stop()
        print("Recording stopped.")
    } catch {
        logger.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
        exit(1)
    }
}

func startStandardOutputCapture(audioProcessController: AudioProcessController) {
    guard let process = audioProcessController.processes.first(where: { $0.name.contains("Spotify") == true }) else {
        logger.error("No audio processes found.")
        exit(1)
    }

    let tap = ProcessTap(process: process)
    let recorder = ProcessTapStandardOut(tap: tap)

    do {
        try recorder.start()
        print("Terminal output started. Press Enter to stop.")
        _ = readLine()
//        recorder.stop()
        print("Terminal output stopped.")
    } catch {
        logger.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
        exit(1)
    }}

Task { @MainActor in
    print("Initializing audio controllers...")
    let audioProcessController = AudioProcessController()
    let audioRecordingPermission = AudioRecordingPermission()

    print("Requesting audio recording permission...")
    await audioRecordingPermission.requestAndWait()

    if audioRecordingPermission.status == .authorized {
        print("Audio recording permission granted.")
        audioProcessController.activate()
//        startRecording(audioProcessController: audioProcessController)
        startStandardOutputCapture(audioProcessController: audioProcessController)
    } else {
        print("Audio recording permission denied.")
        exit(1)
    }
}

RunLoop.main.run()
