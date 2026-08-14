////
//  GitProcess.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// One resolved Git executable, invoked directly with an argument array and an explicit working
/// directory — never through a shell.
///
/// Every failure it reports has the Repository's location redacted, because that text reaches the
/// user's screen and Colofa's own error state.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: process launching
/// and output reading must stay on the caller — `GitRepositoryService` — and off the main actor.
nonisolated struct GitProcess: Sendable {
    let executableURL: URL
    let environment: [String: String]

    /// What ran, kept together so failures can name it without threading two more parameters
    /// through every step.
    private struct Command {
        let arguments: [String]
        let directoryURL: URL
        let sensitiveValues: [String]
    }

    /// Trimmed text output, bounded to the size a single Git answer is expected to need.
    func text(
        _ arguments: [String],
        in directoryURL: URL,
        standardInput: String? = nil
    ) async throws -> String {
        let output = try await data(
            arguments,
            in: directoryURL,
            standardInput: standardInput,
            outputLimit: 4_000
        )
        return Self.string(from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Treats exit status 1 as an empty result, which is how `git config` reports "no matches".
    func dataAllowingNoMatches(
        _ arguments: [String],
        in directoryURL: URL
    ) async throws -> Data {
        do {
            return try await data(arguments, in: directoryURL)
        } catch RepositoryOpenError.commandFailed(let details) where details.exitStatus == 1 {
            return Data()
        }
    }

    func data(
        _ arguments: [String],
        in directoryURL: URL,
        standardInput: String? = nil,
        outputLimit: Int? = nil
    ) async throws -> Data {
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let standardInputPipe = standardInput.map { _ in Pipe() }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL
        process.environment = environment
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
        if let standardInputPipe {
            process.standardInput = standardInputPipe
        }

        let command = Command(
            arguments: arguments,
            directoryURL: directoryURL,
            sensitiveValues: Self.sensitiveValues(from: standardInput)
        )
        do {
            try process.run()
        } catch {
            if !FileManager.default.isExecutableFile(atPath: executableURL.normalizedFilePath) {
                throw RepositoryOpenError.gitUnavailable
            }
            throw RepositoryOpenError.commandFailed(
                failureDetails(of: command, output: error.localizedDescription)
            )
        }

        return try await output(
            of: process,
            running: command,
            standardInput: standardInputPipe.map { ($0, standardInput ?? "") },
            outputPipes: (standardOutputPipe, standardErrorPipe),
            outputLimit: outputLimit
        )
    }

    private func output(
        of process: Process,
        running command: Command,
        standardInput: (pipe: Pipe, text: String)?,
        outputPipes: (standardOutput: Pipe, standardError: Pipe),
        outputLimit: Int?
    ) async throws -> Data {
        // Detached and unawaited until the process exits: input larger than the pipe buffer would
        // otherwise block this task before anything drains Git's output.
        let inputTask = standardInput.map { input in
            Task.detached {
                Self.write(input.text, to: input.pipe.fileHandleForWriting)
            }
        }
        async let standardOutput = Self.readData(
            from: outputPipes.standardOutput.fileHandleForReading,
            limit: outputLimit
        )
        async let standardError = Self.readData(
            from: outputPipes.standardError.fileHandleForReading,
            limit: 4_000
        )
        let exitStatus = await Self.waitForTermination(of: process)
        await inputTask?.value

        let output: Data
        let errorOutput: Data
        do {
            (output, errorOutput) = try await (standardOutput, standardError)
        } catch {
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    of: command,
                    output: error.localizedDescription,
                    exitStatus: exitStatus
                )
            )
        }

        guard exitStatus == 0 else {
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    of: command,
                    output: Self.diagnostic(errorOutput: errorOutput, output: output),
                    exitStatus: exitStatus
                )
            )
        }

        return output
    }

    private func failureDetails(
        of command: Command,
        output: String,
        exitStatus: Int32? = nil
    ) -> GitFailureDetails {
        GitFailureDetails(
            command: redactingLocation(
                of: command.directoryURL,
                in: redactingSensitiveValues(
                    command.sensitiveValues,
                    in: (["git"] + command.arguments).map(\.debugDescription).joined(separator: " ")
                )
            ),
            output: String(
                redactingLocation(
                    of: command.directoryURL,
                    in: redactingSensitiveValues(
                        command.sensitiveValues,
                        in: output.replacing("\0", with: "")
                    )
                ).prefix(4_000)
            ),
            exitStatus: exitStatus
        )
    }

    /// Removes the Repository's location from text Colofa is about to show or store.
    ///
    /// Every spelling is replaced, longest first. Git and hooks report the canonical path, which
    /// on macOS differs from the one the user selected whenever a symlink such as `/tmp` is
    /// involved; without the canonical form that real location would survive in the output.
    private func redactingLocation(of repositoryURL: URL, in text: String) -> String {
        let canonicalPath = try? repositoryURL
            .resourceValues(forKeys: [.canonicalPathKey])
            .canonicalPath
        let paths = Set([repositoryURL.normalizedFilePath, canonicalPath].compactMap { $0 })

        return paths.sorted { $0.count > $1.count }.reduce(text) { redacted, path in
            redacted.replacing(path, with: "<Repository>")
        }
    }

    private func redactingSensitiveValues(_ values: [String], in text: String) -> String {
        values.reduce(text) { redacted, value in
            redactingSensitiveValue(value, in: redacted)
        }
    }

    private func redactingSensitiveValue(_ value: String, in text: String) -> String {
        let replacement = "<Sensitive Input>"
        var redacted = text
        var searchStart = redacted.startIndex

        while let range = redacted.range(of: value, range: searchStart..<redacted.endIndex) {
            let characterBefore = range.lowerBound == redacted.startIndex
                ? nil
                : redacted[redacted.index(before: range.lowerBound)]
            let characterAfter = range.upperBound == redacted.endIndex
                ? nil
                : redacted[range.upperBound]
            guard isSensitiveValueBoundary(characterBefore),
                  isSensitiveValueBoundary(characterAfter) else {
                searchStart = range.upperBound
                continue
            }

            redacted.replaceSubrange(range, with: replacement)
            searchStart = redacted.index(range.lowerBound, offsetBy: replacement.count)
        }
        return redacted
    }

    private func isSensitiveValueBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }
        return !character.isLetter && !character.isNumber && character != "_"
    }

    private static func sensitiveValues(from input: String?) -> [String] {
        guard let input else {
            return []
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = input.split(whereSeparator: \.isNewline).map(String.init)
        return Set([input, trimmed] + lines)
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
    }

    private static func diagnostic(errorOutput: Data, output: Data) -> String {
        [errorOutput, output]
            .map { string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Git's own output is UTF-8. Anything else is still shown rather than dropped: ISO Latin-1
    /// maps every byte, so a Repository with oddly encoded content stays diagnosable.
    private static func string(from data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? String(bytes: data, encoding: .isoLatin1) ?? ""
    }

    private static func readData(from handle: FileHandle, limit: Int?) async throws -> Data {
        var output = Data()
        for try await byte in handle.bytes where output.count < (limit ?? .max) {
            output.append(byte)
        }
        return output
    }

    /// Feeds `text` to the process and closes the pipe, which is what tells Git the input ended.
    ///
    /// A failed write is not reported separately: Git then sees a short or empty input and fails
    /// with its own message, which is the failure the user needs to read.
    private static func write(_ text: String, to handle: FileHandle) {
        defer { try? handle.close() }
        try? handle.write(contentsOf: Data(text.utf8))
    }

    private static func waitForTermination(of process: Process) async -> Int32 {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(returning: process.terminationStatus)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}
