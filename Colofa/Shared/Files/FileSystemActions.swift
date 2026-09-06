////
//  FileSystemActions.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import AppKit

/// The three things Colofa asks the file system and Finder to do with a path the user selected.
///
/// AppKit rather than SwiftUI because none of them has a SwiftUI equivalent: `fileMover` moves a
/// file to a location the user picks rather than to the Trash, nothing in SwiftUI selects a file
/// in Finder, and nothing in SwiftUI hands a local file to whichever app opens it. Kept as a
/// value with closures for the same reason `PasteboardWriter` is — a test can read exactly which
/// URL was trashed, revealed, or opened, which is the only part worth asserting, and no test has
/// to put a real file into the developer's Trash to reach the Store's own logic.
nonisolated struct FileSystemActions: Sendable {
    /// Moves one file to the macOS Trash, throwing whatever the system refused with. A cancelled
    /// authorization arrives as `CocoaError.userCancelled`, which is a different answer from a
    /// failure and is reported as one.
    let moveToTrash: @Sendable (URL) async throws -> Void

    /// Selects one file in Finder.
    ///
    /// - Returns: Whether there was still a file to select. Finder is asked to reveal nothing
    ///   when the path is gone, because it would otherwise open a window on the wrong thing.
    let reveal: @Sendable (URL) async -> Bool

    /// Opens one file in whichever app the system opens that kind of file with, which is where a
    /// conflicted file is edited line by line.
    ///
    /// - Returns: Whether anything opened it. A path that is gone and a path no installed app
    ///   claims are the same answer from the user's side, and both are reported rather than left
    ///   as a click that did nothing.
    let open: @Sendable (URL) async -> Bool

    static func live() -> Self {
        Self(
            moveToTrash: { url in
                try await withCheckedThrowingContinuation { continuation in
                    // `NSWorkspace.recycle` rather than `FileManager.trashItem` because this is
                    // the same Trash operation Finder performs: it reports a cancelled
                    // authorization as a cancellation, and the file stays put either way.
                    NSWorkspace.shared.recycle([url]) { _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            },
            reveal: { url in
                guard await fileExists(at: url) else {
                    return false
                }
                await MainActor.run {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                return true
            },
            open: { url in
                guard await fileExists(at: url) else {
                    return false
                }
                return await MainActor.run {
                    NSWorkspace.shared.open(url)
                }
            }
        )
    }

    /// Asked off the Main Actor, for the same reason the Diff pane asks it there: the file system
    /// can be slow to answer for a Repository on a network volume, and the Main Actor may not
    /// wait on it.
    private static func fileExists(at url: URL) async -> Bool {
        await Task.detached {
            FileManager.default.fileExists(atPath: url.normalizedFilePath)
        }.value
    }
}
