////
//  RepositoryChangeKind.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum RepositoryChangeKind: Hashable, Sendable {
    case modified
    case added
    case deleted
    case renamed(from: String)
    case typeChanged
    case untracked
    case conflict
}
