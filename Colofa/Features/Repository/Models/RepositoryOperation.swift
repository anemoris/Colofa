////
//  RepositoryOperation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Declared `nonisolated` because the project defaults to Main Actor isolation while
/// `GitRepositoryService` decides from an actor which reads one operation still needs.
nonisolated enum RepositoryOperation: Equatable, Sendable {
    case am
    case cherryPick
    case merge
    case rebase
    case revert
}
