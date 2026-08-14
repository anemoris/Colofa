////
//  GitDiffLoader.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads one patch under a limit that is enforced while Git is still writing it.
///
/// Colofa never asks Git for a patch and then decides whether it was too large: reading stops at
/// the bound that applies, so the size of the answer is bounded by the question. A patch that
/// stopped short is measured with a second bounded read that keeps nothing, which is what makes
/// the offer to render it — or the refusal to — an informed one.
nonisolated struct GitDiffLoader: Sendable {
    let git: GitProcess

    func load(_ request: DiffLoadRequest) async throws -> DiffLoadResult {
        let command = GitDiffCommand.patch(for: request.source)
        let bounds = request.isConfirmed
            ? request.limits.hardBounds
            : request.limits.automaticBounds
        let patch = try await git.boundedData(
            command.arguments,
            in: request.repositoryURL,
            bounds: bounds,
            retainsOutput: true,
            successfulExitStatuses: command.successfulExitStatuses
        )

        guard patch.exceedsBounds else {
            return .diff(
                Diff(
                    files: try DiffPatchParser.parse(patch.data),
                    measurement: DiffMeasurement(
                        byteCount: patch.byteCount,
                        lineCount: patch.lineCount,
                        isComplete: true
                    )
                )
            )
        }

        return try await refusal(request, stoppedAt: patch)
    }

    /// Establishes which side of the hard limit a patch that stopped short falls on, without
    /// keeping any of it.
    private func refusal(
        _ request: DiffLoadRequest,
        stoppedAt patch: GitBoundedOutput
    ) async throws -> DiffLoadResult {
        let command = GitDiffCommand.patch(for: request.source)
        // A confirmed read already stopped at the hard bound, so its own counts settle this.
        let measured = request.isConfirmed ? patch : try await git.boundedData(
            command.arguments,
            in: request.repositoryURL,
            bounds: request.limits.hardBounds,
            retainsOutput: false,
            successfulExitStatuses: command.successfulExitStatuses
        )
        let summary = DiffSummary(
            files: try await fileSummaries(request),
            measurement: DiffMeasurement(
                byteCount: measured.byteCount,
                lineCount: measured.lineCount,
                isComplete: !measured.exceedsBounds
            )
        )
        return measured.exceedsBounds
            ? .beyondHardLimit(summary)
            : .confirmationRequired(summary)
    }

    private func fileSummaries(_ request: DiffLoadRequest) async throws -> [DiffFileSummary] {
        let command = GitDiffCommand.numstat(for: request.source)
        // Counting changed lines never writes the patch out, so this answer stays small however
        // large the patch it describes is. It is still bounded, and a summary is refused rather
        // than truncated: a partial list of files would read as a complete one.
        let counts = try await git.boundedData(
            command.arguments,
            in: request.repositoryURL,
            bounds: Self.summaryBounds,
            retainsOutput: true,
            successfulExitStatuses: command.successfulExitStatuses
        )
        guard !counts.exceedsBounds else {
            throw GitOutputParsingError()
        }
        return try DiffNumstatParser.parse(counts.data)
    }

    /// `--numstat -z` writes one short NUL-separated record per file and no newlines at all, so
    /// only the byte bound can be reached here.
    private static let summaryBounds = GitOutputBounds(
        byteCount: 4 * 1_024 * 1_024,
        lineCount: .max
    )
}
