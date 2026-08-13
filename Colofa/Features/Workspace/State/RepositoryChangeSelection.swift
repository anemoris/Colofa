////
//  RepositoryChangeSelection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryChangeSelection: Hashable, Sendable {
    let path: String
    let isStaged: Bool
}
