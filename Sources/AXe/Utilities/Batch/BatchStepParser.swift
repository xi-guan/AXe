import ArgumentParser
import Foundation

enum BatchStepKind: String, CaseIterable {
    case tap
    case swipe
    case gesture
    case touch
    case type
    case button
    case key
    case keySequence = "key-sequence"
    case keyCombo = "key-combo"
    case sleep
}

@MainActor
struct BatchStepParser {
    // Duration.seconds traps on values this large, so bound sleeps well below that
    private static let maximumSleepSeconds: Double = 3600

    static func parseStepTokens(
        _ tokens: [String],
        globalUDID: String,
        context: BatchContext,
        logger: AxeLogger
    ) async throws -> [BatchPrimitive] {
        guard let firstToken = tokens.first else {
            return []
        }

        guard let kind = BatchStepKind(rawValue: firstToken) else {
            let supported = BatchStepKind.allCases.map(\.rawValue).joined(separator: ", ")
            throw ValidationError("Unsupported batch step. Supported steps: \(supported).")
        }

        if kind == .sleep {
            return try parseSleep(tokens)
        }

        let stepArguments = Array(tokens.dropFirst())
        try ensureNoPerStepUDID(stepArguments)
        let arguments = stepArguments + ["--udid", globalUDID]

        switch kind {
        case .tap:
            return try await parseCommand(Tap.self, arguments: arguments, context: context, logger: logger)
        case .swipe:
            return try await parseCommand(Swipe.self, arguments: arguments, context: context, logger: logger)
        case .gesture:
            return try await parseCommand(Gesture.self, arguments: arguments, context: context, logger: logger)
        case .touch:
            return try await parseCommand(Touch.self, arguments: arguments, context: context, logger: logger)
        case .type:
            return try await parseCommand(Type.self, arguments: arguments, context: context, logger: logger)
        case .button:
            return try await parseCommand(Button.self, arguments: arguments, context: context, logger: logger)
        case .key:
            return try await parseCommand(Key.self, arguments: arguments, context: context, logger: logger)
        case .keySequence:
            return try await parseCommand(KeySequence.self, arguments: arguments, context: context, logger: logger)
        case .keyCombo:
            return try await parseCommand(KeyCombo.self, arguments: arguments, context: context, logger: logger)
        case .sleep:
            return []
        }
    }

    private static func parseCommand<C: AsyncParsableCommand & BatchConvertible>(
        _ type: C.Type,
        arguments: [String],
        context: BatchContext,
        logger: AxeLogger
    ) async throws -> [BatchPrimitive] {
        guard var parsed = try C.parseAsRoot(arguments) as? C else {
            throw CLIError(errorDescription: "Failed to parse batch step arguments: \(arguments.joined(separator: " "))")
        }
        try parsed.validate()
        return try await parsed.toBatchPrimitives(context: context, logger: logger)
    }

    private static func ensureNoPerStepUDID(_ args: [String]) throws {
        if args.contains(where: { $0 == "--udid" || $0.hasPrefix("--udid=") }) {
            throw ValidationError("Per-step --udid is not supported in batch steps. Use batch-level --udid.")
        }
    }

    private static func parseSleep(_ tokens: [String]) throws -> [BatchPrimitive] {
        guard tokens.count == 2 else {
            throw ValidationError("Sleep step format: sleep <seconds>")
        }
        guard let seconds = Double(tokens[1]), seconds >= 0, seconds <= maximumSleepSeconds else {
            throw ValidationError("Sleep step requires a number of seconds between 0 and \(Int(maximumSleepSeconds)).")
        }
        return [.hostSleep(seconds)]
    }
}
