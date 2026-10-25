import Foundation
import Testing
@testable import AXe

@Suite("Output File Writer Tests")
struct OutputFileWriterTests {
    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Writing output replaces a planted symlink instead of following it")
    func writeDoesNotFollowSymlink() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let victim = directory.appendingPathComponent("victim.txt")
        let output = directory.appendingPathComponent("shot.png")
        try Data("keep".utf8).write(to: victim)
        try FileManager.default.createSymbolicLink(at: output, withDestinationURL: victim)

        try OutputFileWriter.write(Data("png".utf8), to: output)

        #expect(try Data(contentsOf: victim) == Data("keep".utf8))
        #expect(try Data(contentsOf: output) == Data("png".utf8))
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        #expect(attributes[.type] as? FileAttributeType == .typeRegular)
    }

    @Test("Writing output replaces an existing file and leaves no temporary files")
    func writeReplacesExistingFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("shot.png")
        try Data("old".utf8).write(to: output)

        try OutputFileWriter.write(Data("new".utf8), to: output)

        #expect(try Data(contentsOf: output) == Data("new".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["shot.png"])
    }

    @Test("Preparing a screenshot path keeps the existing file until a capture succeeds")
    func screenshotPreparationKeepsExistingFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("shot.png")
        try Data("old".utf8).write(to: output)

        let command = try Screenshot.parse(["--udid", "EXAMPLE-UDID", "--output", output.path])
        let prepared = try command.prepareOutputURL(simulatorName: "iPhone")

        #expect(prepared.path == output.path)
        #expect(try Data(contentsOf: output) == Data("old".utf8))
    }

    @Test("Preparing a video path keeps the existing file until recording succeeds")
    func videoPreparationKeepsExistingFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("clip.mp4")
        try Data("old".utf8).write(to: output)

        let command = try RecordVideo.parse(["--udid", "EXAMPLE-UDID", "--output", output.path])
        let prepared = try command.prepareOutputURL()

        #expect(prepared.path == output.path)
        #expect(try Data(contentsOf: output) == Data("old".utf8))
    }
}
