import ArgumentParser
import Foundation
import FBSimulatorControl
@preconcurrency import FBControlCore

struct HardwareKeyboard: AsyncParsableCommand {
    enum State: String, CaseIterable, ExpressibleByArgument {
        case on
        case off
    }

    static let configuration = CommandConfiguration(
        commandName: "hardware-keyboard",
        abstract: "Connect or disconnect the simulator hardware keyboard",
        discussion: """
        'off' disconnects the Mac keyboard from the simulator, so focusing a text field shows the iOS software keyboard.
        'on' connects it again. Simulator.app is not touched.

        The first keyboard event sent after boot reconnects the hardware keyboard, so 'off' presses Shift once
        before disconnecting. If the software keyboard still disappears, run the command again.

        Examples:
          axe hardware-keyboard off --udid SIMULATOR_UDID
          axe hardware-keyboard on --udid SIMULATOR_UDID
        """
    )

    private static let leftShiftKeyCode: UInt32 = 225

    @Argument(help: "'off' disconnects the hardware keyboard so the software keyboard appears; 'on' connects it again.")
    var state: State

    @Option(name: .customLong("udid"), help: "The UDID of the simulator.")
    var simulatorUDID: String

    func validate() throws {
        guard !simulatorUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("Simulator UDID cannot be empty. Use --udid to specify a simulator.")
        }
    }

    func run() async throws {
        let logger = AxeLogger()
        try await performGlobalSetup(logger: logger)

        let trimmedUDID = simulatorUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        let simulatorSet = try await getSimulatorSet(deviceSetPath: nil, logger: logger, reporter: EmptyEventReporter.shared)
        guard let targetSimulator = simulatorSet.allSimulators.first(where: { $0.udid == trimmedUDID }) else {
            throw CLIError.simulatorNotFound(udid: trimmedUDID)
        }

        guard targetSimulator.state == .booted else {
            let stateDescription = FBiOSTargetStateStringFromState(targetSimulator.state).rawValue
            throw CLIError(errorDescription: "Simulator \(trimmedUDID) is not booted. Current state: \(stateDescription)")
        }

        if state == .off {
            // the first keyboard HID event after boot reconnects the hardware keyboard, so spend it on Shift first
            try await HIDInteractor.performHIDEvent(FBSimulatorHIDEvent.shortKeyPress(Self.leftShiftKeyCode), for: trimmedUDID, logger: logger)
        }

        do {
            try await targetSimulator.setSetting(.hardwareKeyboard, enabled: state == .on)
        } catch {
            throw CLIError(errorDescription: "Failed to turn the hardware keyboard \(state.rawValue) for simulator \(trimmedUDID): \(error.localizedDescription)")
        }

        print("Hardware keyboard \(state == .on ? "connected" : "disconnected") for simulator \(trimmedUDID)")
    }
}
