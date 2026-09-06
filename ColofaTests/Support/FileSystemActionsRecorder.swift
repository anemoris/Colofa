////
//  FileSystemActionsRecorder.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// A file system that records what it was asked to do instead of doing it, so a Store-level test
/// can reach every answer — moved, cancelled, refused, already gone — without putting a real file
/// into the developer's Trash. That the live boundary actually uses the macOS Trash is
/// `FileActionsIntegrationTests`' job.
@MainActor
final class FileSystemActionsRecorder {
    private(set) var trashed: [URL] = []
    private(set) var revealed: [URL] = []
    private(set) var opened: [URL] = []

    /// What the Trash refuses with, or `nil` when it accepts. A `CocoaError` because that is what
    /// the real boundary throws, cancellation included.
    var trashError: CocoaError?

    /// The paths Finder and the system open nothing at, which is how a path that disappeared
    /// before the click is driven.
    var missingPaths: Set<String> = []

    var actions: FileSystemActions {
        FileSystemActions(
            moveToTrash: { [self] url in
                try await MainActor.run {
                    trashed.append(url)
                    if let trashError {
                        throw trashError
                    }
                }
            },
            reveal: { [self] url in
                await MainActor.run {
                    revealed.append(url)
                    return !missingPaths.contains(url.normalizedFilePath)
                }
            },
            open: { [self] url in
                await MainActor.run {
                    opened.append(url)
                    return !missingPaths.contains(url.normalizedFilePath)
                }
            }
        )
    }
}
