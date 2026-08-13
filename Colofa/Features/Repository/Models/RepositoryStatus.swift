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
    let upstream: RepositoryUpstream?
    let stagedChanges: [RepositoryChange]
    let unstagedChanges: [RepositoryChange]
}
