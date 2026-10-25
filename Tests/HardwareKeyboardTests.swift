import ArgumentParser
import Foundation
import Testing
@testable import AXe

@Suite("Hardware Keyboard Command Tests")
@MainActor
struct HardwareKeyboardTests {
    @Test("Parses on and off")
    func parsesStates() throws {
        let on = try HardwareKeyboard.parse(["on", "--udid", "EXAMPLE-UDID"])
        #expect(on.state == .on)
        #expect(on.simulatorUDID == "EXAMPLE-UDID")

        let off = try HardwareKeyboard.parse(["off", "--udid", "EXAMPLE-UDID"])
        #expect(off.state == .off)
    }

    @Test("Rejects states other than on and off")
    func rejectsUnknownState() {
        for state in ["true", "enable", "ON", "1"] {
            #expect(throws: (any Error).self) {
                _ = try HardwareKeyboard.parse([state, "--udid", "EXAMPLE-UDID"])
            }
        }
    }

    @Test("Requires a state and a non-empty UDID")
    func requiresStateAndUDID() {
        #expect(throws: (any Error).self) {
            _ = try HardwareKeyboard.parse(["--udid", "EXAMPLE-UDID"])
        }
        #expect(throws: (any Error).self) {
            _ = try HardwareKeyboard.parse(["off"])
        }
        #expect(throws: (any Error).self) {
            _ = try HardwareKeyboard.parse(["off", "--udid", "  "])
        }
    }

    @Test("Is registered as an axe subcommand")
    func isRegistered() {
        let names = Axe.configuration.subcommands.compactMap { $0.configuration.commandName }
        #expect(names.contains("hardware-keyboard"))
    }
}
