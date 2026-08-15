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
        return String(gitBytes: output)
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

    /// Reads standard output while counting it, and stops the moment it passes `bounds`.
    ///
    /// A patch Colofa has already decided not to render must not be read to the end first, so
    /// crossing a bound ends Git rather than draining it, and the output collected so far is
    /// dropped rather than retained. `retainsOutput` is what separates reading a patch from only
    /// measuring one.
    ///
    /// - Parameter successfulExitStatuses: The statuses that mean the command answered rather
    ///   than failed. A stopped read reports Colofa's own decision, so its status is not checked.
    func boundedData(
        _ arguments: [String],
        in directoryURL: URL,
        bounds: GitOutputBounds,
        retainsOutput: Bool,
        successfulExitStatuses: Set<Int32> = [0]
    ) async throws -> GitBoundedOutput {
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL
        process.environment = environment
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        let command = Command(
            arguments: arguments,
            directoryURL: directoryURL,
            sensitiveValues: []
        )
        try launch(process, running: command)

        async let errorOutput = GitProcessIO.readData(
            from: standardErrorPipe.fileHandleForReading,
            limit: 4_000
        )
        let read = await Self.boundedRead(
            from: standardOutputPipe.fileHandleForReading,
            of: process,
            bounds: bounds,
            retainsOutput: retainsOutput
        )
        let exitStatus = await GitProcessIO.waitForTermination(of: process)
        let errorOutputData = try? await errorOutput

        // A cancelled read ends where Git was killed, not where the output did. Reporting what
        // arrived would be reporting a patch that was cut off as a whole one.
        try Task.checkCancellation()

        return try validated(
            read,
            of: command,
            exitStatus: exitStatus,
            errorOutput: errorOutputData,
            successfulExitStatuses: successfulExitStatuses
        )
    }

    /// - Parameter errorOutput: What Git wrote to standard error, or `nil` when reading it
    ///   failed.
    private func validated(
        _ read: Result<GitBoundedOutput, any Error>,
        of command: Command,
        exitStatus: Int32,
        errorOutput: Data?,
        successfulExitStatuses: Set<Int32>
    ) throws -> GitBoundedOutput {
        let output: GitBoundedOutput
        switch read {
        case .failure(let error):
            throw RepositoryOpenError.commandFailed(
                failureDetails(of: command, output: error.localizedDescription, exitStatus: exitStatus)
            )
        case .success(let value):
            output = value
        }

        // A status Colofa accepts as an answer rather than a failure only counts as one when Git
        // said nothing while returning it. `git diff --no-index` reports both "these differ" and
        // "I could not read that" as status 1, and only the second writes to standard error — so
        // a missing file would otherwise be read back as a Diff with nothing in it. Standard
        // error Colofa failed to read counts as present, because assuming it was empty is the
        // assumption that turns a failure into an answer.
        let answeredQuietly = exitStatus == 0
            || (successfulExitStatuses.contains(exitStatus) && errorOutput?.isEmpty == true)
        guard output.exceedsBounds || answeredQuietly else {
            throw RepositoryOpenError.commandFailed(
                failureDetails(
                    of: command,
                    output: GitProcessIO.diagnostic(
                        errorOutput: errorOutput ?? Data(),
                        output: Data()
                    ),
                    exitStatus: exitStatus
                )
            )
        }
        return output
    }

    /// Reads bounded output and makes sure Git ends afterwards, whether the read stopped at a
    /// bound, failed, or was cancelled — each of them leaves Git writing to nobody.
    private static func boundedRead(
        from handle: FileHandle,
        of process: Process,
        bounds: GitOutputBounds,
        retainsOutput: Bool
    ) async -> Result<GitBoundedOutput, any Error> {
        let read: Result<GitBoundedOutput, any Error>
        do {
            // The read blocks on a thread of its own, so cancellation has to reach it by ending
            // Git: closing the pipe is what returns the blocked read at once.
            read = .success(
                try await withTaskCancellationHandler {
                    try await GitBoundedReader.read(
                        from: handle,
                        bounds: bounds,
                        retainsOutput: retainsOutput
                    )
                } onCancel: {
                    process.terminate()
                }
            )
        } catch {
            read = .failure(error)
        }

        if (try? read.get())?.exceedsBounds ?? true, process.isRunning {
            process.terminate()
        }
        return read
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
            sensitiveValues: GitOutputRedaction.sensitiveValues(from: standardInput)
        )
        try launch(process, running: command)

        return try await output(
            of: process,
            running: command,
            standardInput: standardInputPipe.map { ($0, standardInput ?? "") },
            outputPipes: (standardOutputPipe, standardErrorPipe),
            outputLimit: outputLimit
        )
    }

    private func launch(_ process: Process, running command: Command) throws {
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
                GitProcessIO.write(input.text, to: input.pipe.fileHandleForWriting)
            }
        }
        async let standardOutput = GitProcessIO.readData(
            from: outputPipes.standardOutput.fileHandleForReading,
            limit: outputLimit
        )
        async let standardError = GitProcessIO.readData(
            from: outputPipes.standardError.fileHandleForReading,
            limit: 4_000
        )
        let exitStatus = await GitProcessIO.waitForTermination(of: process)
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
                    output: GitProcessIO.diagnostic(errorOutput: errorOutput, output: output),
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
            command: GitOutputRedaction.redactingLocation(
                of: command.directoryURL,
                in: GitOutputRedaction.redactingSensitiveValues(
                    command.sensitiveValues,
                    in: (["git"] + command.arguments).map(\.debugDescription).joined(separator: " ")
                )
            ),
            output: String(
                GitOutputRedaction.redactingLocation(
                    of: command.directoryURL,
                    in: GitOutputRedaction.redactingSensitiveValues(
                        command.sensitiveValues,
                        in: output.replacing("\0", with: "")
                    )
                ).prefix(4_000)
            ),
            exitStatus: exitStatus
        )
    }
}
