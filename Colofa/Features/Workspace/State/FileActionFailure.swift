////
//  FileActionFailure.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What the file system answered when Colofa asked it to remove or reveal a changed path.
///
/// Separate from `RepositoryOpenError` because no Git command ran: there is no command line to
/// echo back and no Git output to redact, so these carry the path and the system's own reason
/// instead of failure details nobody could expand.
enum FileActionFailure: Equatable, Sendable {
    /// The Trash operation was cancelled rather than refused — an authorization the user
    /// declined. The file is still where it was.
    case trashCancelled(path: String)
    case trashFailed(path: String, reason: String)
    /// The path was already gone when Finder was asked for it, so the Repository was read again.
    case revealMissing(path: String)

    var title: LocalizedStringResource {
        switch self {
        case .trashCancelled: .moveToTrashCancelledTitle
        case .trashFailed: .moveToTrashFailedTitle
        case .revealMissing: .revealInFinderFailedTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .trashCancelled(let path):
            .moveToTrashCancelledMessage(path)
        case .trashFailed(let path, let reason):
            .moveToTrashFailedMessage(path, reason)
        case .revealMissing(let path):
            .revealInFinderFailedMessage(path)
        }
    }
}
