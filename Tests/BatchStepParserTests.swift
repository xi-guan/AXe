import Foundation
import Testing
@testable import AXe

@Suite("Batch Step Parser Tests")
@MainActor
struct BatchStepParserTests {
    private let secretLine = "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAAB"

    private func makeContext() -> BatchContext {
        BatchContext(
            simulatorUDID: "EXAMPLE-UDID",
            axCachePolicy: .none,
            typeSubmissionMode: .chunked,
            typeChunkSize: 200
        )
    }

    @Test("Unsupported step errors do not echo the step text")
    func unsupportedStepDoesNotEchoInput() async throws {
        do {
            _ = try await BatchStepParser.parseStepTokens(
                [secretLine],
                globalUDID: "EXAMPLE-UDID",
                context: makeContext(),
                logger: AxeLogger()
            )
            Issue.record("Expected an unsupported step error.")
        } catch {
            #expect(!String(describing: error).contains(secretLine))
            #expect(!error.localizedDescription.contains(secretLine))
            #expect(!Batch.stepFailureReason(for: error).contains(secretLine))
        }
    }

    @Test("Batch failures show the batch step validation message")
    func failureReasonShowsSleepValidationMessage() async throws {
        do {
            _ = try await BatchStepParser.parseStepTokens(
                ["sleep", "99999"],
                globalUDID: "EXAMPLE-UDID",
                context: makeContext(),
                logger: AxeLogger()
            )
            Issue.record("Expected a sleep validation error.")
        } catch {
            #expect(Batch.stepFailureReason(for: error).contains("between 0 and 3600"))
        }
    }

    @Test("Batch failures show the step command validation message")
    func failureReasonShowsCommandValidationMessage() async throws {
        do {
            _ = try await BatchStepParser.parseStepTokens(
                ["swipe", "--start-x", "0", "--start-y", "0", "--end-x", "100", "--end-y", "100", "--delta", "0.0001"],
                globalUDID: "EXAMPLE-UDID",
                context: makeContext(),
                logger: AxeLogger()
            )
            Issue.record("Expected a swipe validation error.")
        } catch {
            #expect(Batch.stepFailureReason(for: error).contains("Delta is too small"))
        }
    }

    @Test("Batch failure labels name only supported steps")
    func failureLabelHidesUnsupportedTokens() {
        #expect(Batch.stepLabel(for: ["tap", "-x", "1"]) == "tap")
        #expect(Batch.stepLabel(for: ["key-sequence", "--keycodes", "4"]) == "key-sequence")
        #expect(Batch.stepLabel(for: [secretLine]) == "<unsupported>")
        #expect(Batch.stepLabel(for: []) == "<empty>")
    }
}
