////
//  RepositoryStatus.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryStatus: Equatable, Sendable {
    let head: RepositoryHead

    /// The full object ID of the Commit HEAD points at, or `nil` on an Unborn Branch.
    let headObjectID: String?

    let upstream: RepositoryUpstream?
    let stagedChanges: [RepositoryChange]
    let unstagedChanges: [RepositoryChange]
}
