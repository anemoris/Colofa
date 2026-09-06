////
//  UITestingRepositoryService+FileSystem.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

#if DEBUG
import Foundation

/// The file system a UI test's Move to Trash, Reveal in Finder, and Open in Default Editor
/// reach.
///
/// It lives on the Repository stub rather than beside it because the two answers have to agree:
/// a path the Trash accepted is a path the next Repository read must no longer report.
extension UITestingRepositoryService {
    /// Removes an untracked path the way the Trash does, without a Trash: the row goes, and the
    /// Repository the next read publishes no longer reports it.
    func moveToTrash(_ url: URL) throws {
        if arguments.contains(UITestingArgument.trashFailure) {
            throw CocoaError(.fileWriteNoPermission)
        }
        guard let snapshot, url.normalizedFilePath.hasPrefix(snapshot.rootURL.normalizedFilePath)
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        let path = String(
            url.normalizedFilePath.dropFirst(snapshot.rootURL.normalizedFilePath.count + 1)
        )
        self.snapshot = replacing(
            in: snapshot,
            unstaged: snapshot.unstagedChanges.filter { $0.path != path }
        )
    }

    /// Answers for Finder without opening it. A path the fixture was told is gone is the case
    /// Reveal in Finder explains rather than shows.
    func reveal(_ url: URL) -> Bool {
        !arguments.contains(UITestingArgument.missingFile)
    }

    /// Answers for the system's own opener without launching an app, so a UI test resolving a
    /// Conflict never takes an editor to the foreground on the machine running it.
    func open(_ url: URL) -> Bool {
        !arguments.contains(UITestingArgument.missingFile)
    }
}
#endif
