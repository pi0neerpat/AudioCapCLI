import Foundation
import AudioToolbox
import OSLog
import Combine

struct AudioProcess: Identifiable, Hashable {
    var id: pid_t
    var name: String
    var bundleURL: URL?
    var objectID: AudioObjectID
}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}

final class AudioProcessController {

    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioProcessController.self))

    private(set) var processes = [AudioProcess]()

    private var cancellables = Set<AnyCancellable>()

    func activate() {
        logger.debug(#function)

        // Replace NSWorkspace usage
        getRunningApplications()
            .sink { [weak self] apps in
                guard let self else { return }
                self.reload(apps: apps)
            }
            .store(in: &cancellables)
    }

    fileprivate func reload(apps: [ProcessInfo]) {
        logger.debug(#function)

        do {
            let objectIdentifiers = try AudioObjectID.readProcessList()
            
            let updatedProcesses: [AudioProcess] = objectIdentifiers.compactMap { objectID in
                do {
                    let pid: pid_t = try objectID.read(kAudioProcessPropertyPID, defaultValue: -1)

                    guard let app = apps.first(where: { $0.processIdentifier == pid }) else { return nil }

                    return AudioProcess(id: app.processIdentifier, name: app.name ?? "Unknown", bundleURL: nil, objectID: objectID)
                } catch {
                    logger.warning("Failed to initialize process with object ID #\(objectID, privacy: .public): \(error, privacy: .public)")
                    return nil
                }
            }

            self.processes = updatedProcesses
                .sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        } catch {
            logger.error("Error reading process list: \(error, privacy: .public)")
        }
    }

    private func getRunningApplications() -> AnyPublisher<[ProcessInfo], Never> {
        // Replace with a method to fetch running processes without AppKit
        // For example, use `ps` command or similar
        return Just([]).eraseToAnyPublisher()
    }
}

private extension ProcessInfo {
    var processIdentifier: pid_t {
        // Return process identifier
        return 0 // Placeholder
    }

    var name: String? {
        // Return process name
        return nil // Placeholder
    }
}
