////
//  RepositoryReferences.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryReferences: Equatable, Sendable {
    let localBranches: [String]
    let remoteBranches: [String]
    let tags: [String]
}
