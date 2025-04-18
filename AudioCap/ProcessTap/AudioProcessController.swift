import SwiftUI
import Foundation
import AudioToolbox
import OSLog
import Combine

struct AudioProcess: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case process
        case app
    }
    var id: pid_t
    var kind: Kind
    var name: String
    var audioActive: Bool
    var bundleID: String?
    var bundleURL: URL?
    var objectID: AudioObjectID
    var streamDescription: AudioStreamBasicDescription?

    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }

    // Add Equatable conformance
    static func == (lhs: AudioProcess, rhs: AudioProcess) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

struct AudioProcessGroup: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var processes: [AudioProcess]
}

extension AudioProcess.Kind {
    var defaultIcon: NSImage {
        switch self {
        case .process: NSWorkspace.shared.icon(for: .unixExecutable)
        case .app: NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }
}

extension AudioProcess {
    var icon: NSImage {
        // For non-browser helpers - use direct bundleURL
        if let bundleURL = bundleURL, bundleID.map(isBrowserHelper) != true {
            let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
            image.size = NSSize(width: 32, height: 32)
            return image
        }
        
        // For browser helpers - map to main app
        if let bundleID = bundleID, let mainAppBundleID = helperToMainAppBundleID(bundleID),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppBundleID) {
            let image = NSWorkspace.shared.icon(forFile: appURL.path)
            image.size = NSSize(width: 32, height: 32)
            return image
        }
        
        // Fall back to default icon if all else fails
        return kind.defaultIcon
    }
    
    // Function to check if a bundle ID belongs to a known browser helper
    private func isBrowserHelper(_ bundleID: String) -> Bool {
        return bundleID.contains(".helper") || bundleID.contains("WebKit.GPU")
    }
    
    // Map helper bundle IDs to their main application bundle IDs
    private func helperToMainAppBundleID(_ bundleID: String) -> String? {
        let mapping: [String: String] = [
            "com.google.Chrome.helper": "com.google.Chrome",
            "com.brave.Browser.helper": "com.brave.Browser",
            "company.thebrowser.browser.helper": "company.thebrowser.browser",
            "com.apple.WebKit.GPU": "com.apple.Safari",
        ]
        
        return mapping[bundleID]
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}

@MainActor
@Observable
final class AudioProcessController {

    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioProcessController.self))

    private(set) var processes = [AudioProcess]() {
        didSet {
            guard processes != oldValue else { return }

            processGroups = AudioProcessGroup.groups(with: processes)
        }
    }

    private(set) var processGroups = [AudioProcessGroup]()

    private var cancellables = Set<AnyCancellable>()

    func activate() {
        logger.debug(#function)

        NSWorkspace.shared
            .publisher(for: \.runningApplications, options: [.initial, .new])
            .map { $0.filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) }
            .sink { [weak self] apps in
                guard let self else { return }
                self.reload(apps: apps)
            }
            .store(in: &cancellables)
    }

    fileprivate func reload(apps: [NSRunningApplication]) {
        logger.debug(#function)

        do {
            let objectIdentifiers = try AudioObjectID.readProcessList()
            
            let updatedProcesses: [AudioProcess] = objectIdentifiers.compactMap { objectID in
                do {
                    let proc = try AudioProcess(objectID: objectID, runningApplications: apps)

                    #if DEBUG
                    if UserDefaults.standard.bool(forKey: "ACDumpProcessInfo") {
                        logger.debug("[PROCESS] \(String(describing: proc))")
                    }
                    #endif

                    return proc
                } catch {
                    logger.warning("Failed to initialize process with object ID #\(objectID, privacy: .public): \(error, privacy: .public)")
                    return nil
                }
            }

            self.processes = updatedProcesses
                .sorted { // Keep processes with audio active always on top
                    if $0.name.localizedStandardCompare($1.name) == .orderedAscending {
                        $1.audioActive && !$0.audioActive ? false : true
                    } else {
                        $0.audioActive && !$1.audioActive ? true : false
                    }
                }
        } catch {
            logger.error("Error reading process list: \(error, privacy: .public)")
        }
    }
}

private extension AudioProcess {
    init(app: NSRunningApplication, objectID: AudioObjectID) {
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? app.bundleIdentifier?.components(separatedBy: ".").last ?? "Unknown \(app.processIdentifier)"

        // Try to get the audio format by creating a temporary tap description
        var streamDescription: AudioStreamBasicDescription?
        do {
            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [objectID])
            var tapID: AUAudioObjectID = .unknown
            let err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
            if err == noErr {
                streamDescription = try tapID.readAudioTapStreamBasicDescription()
                // Clean up the temporary tap
                _ = AudioHardwareDestroyProcessTap(tapID)
            }
        } catch {
            print("Failed to read format: \(error)")
        }

        self.init(
            id: app.processIdentifier,
            kind: .app,
            name: name,
            audioActive: objectID.readProcessIsRunning(),
            bundleID: app.bundleIdentifier,
            bundleURL: app.bundleURL,
            objectID: objectID,
            streamDescription: streamDescription
        )
    }

    init(objectID: AudioObjectID, runningApplications apps: [NSRunningApplication]) throws {
        let pid: pid_t = try objectID.read(kAudioProcessPropertyPID, defaultValue: -1)

        if let app = apps.first(where: { $0.processIdentifier == pid }) {
            self.init(app: app, objectID: objectID)
        } else {
            try self.init(objectID: objectID, pid: pid)
        }
    }

    init(objectID: AudioObjectID, pid: pid_t) throws {
        let bundleID = objectID.readProcessBundleID()
        let bundleURL: URL?
        let name: String

        (name, bundleURL) = if let info = processInfo(for: pid) {
            (info.name, URL(fileURLWithPath: info.path).parentBundleURL())
        } else if let id = bundleID?.lastReverseDNSComponent {
            (id, nil)
        } else {
            ("Unknown (\(pid))", nil)
        }

        // Try to get the audio format by creating a temporary tap description
        var streamDescription: AudioStreamBasicDescription?
        do {
            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [objectID])
            var tapID: AUAudioObjectID = .unknown
            let err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
            if err == noErr {
                streamDescription = try tapID.readAudioTapStreamBasicDescription()
                // Clean up the temporary tap
                _ = AudioHardwareDestroyProcessTap(tapID)
            }
        } catch {
            print("Failed to read format: \(error)")
        }

        self.init(
            id: pid,
            kind: bundleURL?.isApp == true ? .app : .process,
            name: name,
            audioActive: objectID.readProcessIsRunning(),
            bundleID: bundleID.flatMap { $0.isEmpty ? nil : $0 },
            bundleURL: bundleURL,
            objectID: objectID,
            streamDescription: streamDescription
        )
    }
}

// MARK: - Grouping

extension AudioProcessGroup {
    static func groups(with processes: [AudioProcess]) -> [AudioProcessGroup] {
        var byKind = [AudioProcess.Kind: AudioProcessGroup]()

        for process in processes {
            byKind[process.kind, default: .init(for: process.kind)].processes.append(process)
        }

        return byKind.values.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
    }
}

extension AudioProcessGroup {
    init(for kind: AudioProcess.Kind) {
        self.init(id: kind.rawValue, title: kind.groupTitle, processes: [])
    }
}

extension AudioProcess.Kind {
    var groupTitle: String {
        switch self {
        case .process: "Processes"
        case .app: "Apps"
        }
    }
}

// MARK: - Helpers

private func processInfo(for pid: pid_t) -> (name: String, path: String)? {
    let nameBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
    let pathBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))

    defer {
        nameBuffer.deallocate()
        pathBuffer.deallocate()
    }

    let nameLength = proc_name(pid, nameBuffer, UInt32(MAXPATHLEN))
    let pathLength = proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))

    guard nameLength > 0, pathLength > 0 else {
        return nil
    }

    let name = String(cString: nameBuffer)
    let path = String(cString: pathBuffer)

    return (name, path)
}

private extension String {
    var lastReverseDNSComponent: String? {
        components(separatedBy: ".").last.flatMap { $0.isEmpty ? nil : $0 }
    }
}

private extension URL {
    func parentBundleURL(maxDepth: Int = 8) -> URL? {
        var depth = 0
        var url = deletingLastPathComponent()
        while depth < maxDepth, !url.isBundle {
            url = url.deletingLastPathComponent()
            depth += 1
        }
        return url.isBundle ? url : nil
    }

    var isBundle: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .bundle) == true
    }

    var isApp: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .application) == true
    }
}

