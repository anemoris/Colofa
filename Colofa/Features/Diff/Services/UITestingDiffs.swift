////
//  UITestingDiffs.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The Diff states UI tests select by choosing a path.
///
/// Every text case is written as a real patch and read back through `DiffPatchParser`, so the
/// fixtures assert against the same parsing the app does rather than against a hand-built model
/// that could drift away from it.
nonisolated enum UITestingDiffs {
    static let textPath = "diff.txt"
    static let renamedPath = "renamed 名称.txt"
    static let originalPath = "old name.txt"
    static let binaryPath = "image.bin"
    static let submodulePath = "vendor/module"
    static let confirmationPath = "large.txt"
    static let beyondLimitPath = "huge.bin"
    /// Beyond a hard limit and gone from the working tree, which is what a large deletion looks
    /// like: there is no file left to open.
    static let deletedBeyondLimitPath = "deleted-huge.txt"
    /// Answers only once the UI test releases it, which is the one way a UI test can see the state
    /// the pane shows while a real patch is being read.
    static let slowPath = "slow.txt"

    static func result(for request: DiffLoadRequest) async throws -> DiffLoadResult {
        if request.source.path == slowPath {
            try await UITestingSlowDiff.waitForRelease(in: request.repositoryURL)
            return .diff(try parse(textPatch))
        }
        return switch request.source.path {
        case renamedPath:
            .diff(try parse(renamedPatch))
        case binaryPath:
            .diff(try parse(binaryPatch))
        case submodulePath:
            .diff(try parse(submodulePatch))
        case confirmationPath where request.isConfirmed:
            .diff(try parse(textPatch))
        case confirmationPath:
            .confirmationRequired(
                summary(
                    path: confirmationPath,
                    stats: DiffStats(additions: 42_118, deletions: 3_004),
                    byteCount: 3_565_158,
                    lineCount: 45_122,
                    isComplete: true
                )
            )
        case deletedBeyondLimitPath:
            .beyondHardLimit(
                refusedSummary(
                    path: deletedBeyondLimitPath,
                    stats: DiffStats(additions: 0, deletions: 220_418)
                )
            )
        case beyondLimitPath:
            .beyondHardLimit(refusedSummary(path: beyondLimitPath, stats: nil))
        default:
            .diff(try parse(textPatch))
        }
    }

    /// A patch that stopped at the hard limits, so its measurement is a floor.
    private static func refusedSummary(path: String, stats: DiffStats?) -> DiffSummary {
        summary(
            path: path,
            stats: stats,
            byteCount: 10 * 1_024 * 1_024,
            lineCount: 100_000,
            isComplete: false
        )
    }

    private static func summary(
        path: String,
        stats: DiffStats?,
        byteCount: Int,
        lineCount: Int,
        isComplete: Bool
    ) -> DiffSummary {
        DiffSummary(
            files: [DiffFileSummary(oldPath: nil, newPath: path, stats: stats)],
            measurement: DiffMeasurement(
                byteCount: byteCount,
                lineCount: lineCount,
                isComplete: isComplete
            )
        )
    }

    private static func parse(_ patch: String) throws -> Diff {
        let data = Data(patch.utf8)
        return Diff(
            files: try DiffPatchParser.parse(data),
            measurement: DiffMeasurement(
                byteCount: data.count,
                lineCount: patch.split(separator: "\n").count,
                isComplete: true
            )
        )
    }

    private static let textPatch = """
    diff --git a/diff.txt b/diff.txt
    index 1111111..2222222 100644
    --- a/diff.txt
    +++ b/diff.txt
    @@ -1,4 +1,5 @@ func load()
     first context line
    -removed line
    +added line
    +second added line
     trailing context
    @@ -20,3 +21,3 @@ func store()
     stored context
    -old tail
    +new tail
    \\ No newline at end of file

    """

    private static let renamedPatch = """
    diff --git a/old name.txt b/renamed 名称.txt
    similarity index 82%
    rename from old name.txt
    rename to renamed 名称.txt
    index 3333333..4444444 100644
    --- a/old name.txt
    +++ b/renamed 名称.txt
    @@ -1,2 +1,2 @@
     kept line
    -old content
    +new content

    """

    private static let binaryPatch = """
    diff --git a/image.bin b/image.bin
    index 5555555..6666666 100644
    Binary files a/image.bin and b/image.bin differ

    """

    private static let submodulePatch = """
    diff --git a/vendor/module b/vendor/module
    index aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 160000
    --- a/vendor/module
    +++ b/vendor/module
    @@ -1 +1 @@
    -Subproject commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    +Subproject commit bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

    """
}
#endif
