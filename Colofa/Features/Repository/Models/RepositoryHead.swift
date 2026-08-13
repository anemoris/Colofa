////
//  RepositoryHead.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

enum RepositoryHead: Equatable, Sendable {
    case branch(String)
    case unbornBranch(String)
    case detached(String)
}
