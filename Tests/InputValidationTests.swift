import ArgumentParser
import Foundation
import Testing
@testable import AXe

@Suite("Input Validation Tests")
@MainActor
struct InputValidationTests {
    @Test("Swipe rejects deltas that would create an unbounded number of steps")
    func swipeRejectsTinyDelta() {
        #expect(throws: (any Error).self) {
            _ = try Swipe.parse([
                "--start-x", "0", "--start-y", "0", "--end-x", "300", "--end-y", "600",
                "--delta", "1e-12", "--udid", "EXAMPLE-UDID",
            ])
        }
        #expect(throws: Never.self) {
            _ = try Swipe.parse([
                "--start-x", "0", "--start-y", "0", "--end-x", "300", "--end-y", "600",
                "--delta", "0.5", "--udid", "EXAMPLE-UDID",
            ])
        }
    }

    @Test("Swipe rejects non-finite coordinates and durations")
    func swipeRejectsNonFiniteValues() {
        #expect(throws: (any Error).self) {
            _ = try Swipe.parse([
                "--start-x", "inf", "--start-y", "0", "--end-x", "300", "--end-y", "600",
                "--udid", "EXAMPLE-UDID",
            ])
        }
        #expect(throws: (any Error).self) {
            _ = try Swipe.parse([
                "--start-x", "0", "--start-y", "0", "--end-x", "300", "--end-y", "600",
                "--duration", "inf", "--udid", "EXAMPLE-UDID",
            ])
        }
    }

    @Test("Gesture enforces its documented minimum delta")
    func gestureRejectsSubPixelDelta() {
        #expect(throws: (any Error).self) {
            _ = try Gesture.parse(["scroll-up", "--delta", "1e-12", "--udid", "EXAMPLE-UDID"])
        }
        #expect(throws: Never.self) {
            _ = try Gesture.parse(["scroll-up", "--delta", "1", "--udid", "EXAMPLE-UDID"])
        }
    }

    @Test("Coordinate commands reject non-finite coordinates")
    func coordinateCommandsRejectInfinity() {
        #expect(throws: (any Error).self) {
            _ = try Tap.parse(["-x", "inf", "-y", "10", "--udid", "EXAMPLE-UDID"])
        }
        #expect(throws: (any Error).self) {
            _ = try Touch.parse(["-x", "10", "-y", "inf", "--down", "--udid", "EXAMPLE-UDID"])
        }
        #expect(throws: (any Error).self) {
            _ = try Drag.parse([
                "--start-x", "0", "--start-y", "0", "--end-x", "inf", "--end-y", "10",
                "--udid", "EXAMPLE-UDID",
            ])
        }
    }

    @Test("Batch sleep rejects non-finite and excessive durations")
    func batchSleepIsBounded() async throws {
        let context = BatchContext(
            simulatorUDID: "EXAMPLE-UDID",
            axCachePolicy: .none,
            typeSubmissionMode: .chunked,
            typeChunkSize: 200
        )
        for seconds in ["inf", "1e300", "3601"] {
            await #expect(throws: (any Error).self) {
                _ = try await BatchStepParser.parseStepTokens(
                    ["sleep", seconds],
                    globalUDID: "EXAMPLE-UDID",
                    context: context,
                    logger: AxeLogger()
                )
            }
        }
        let primitives = try await BatchStepParser.parseStepTokens(
            ["sleep", "1.5"],
            globalUDID: "EXAMPLE-UDID",
            context: context,
            logger: AxeLogger()
        )
        #expect(primitives.count == 1)
    }
}
