import Darwin
import Foundation

enum OutputFileWriter {
    static func write(_ data: Data, to destination: URL) throws {
        let temporaryURL = temporaryURL(nextTo: destination)
        do {
            try data.write(to: temporaryURL, options: .withoutOverwriting)
            try replaceItem(at: destination, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    // same directory keeps rename(2) atomic; the random prefix keeps the name unguessable in shared dirs
    static func temporaryURL(nextTo destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appendingPathComponent(".axe-\(UUID().uuidString)-\(destination.lastPathComponent)")
    }

    // rename(2) replaces a symlink at the destination instead of writing through it
    static func replaceItem(at destination: URL, withItemAt source: URL) throws {
        guard rename(source.path, destination.path) == 0 else {
            let reason = String(cString: strerror(errno))
            throw CLIError(errorDescription: "Failed to save \(destination.path): \(reason)")
        }
    }
}
