////
//  RepositoryRemote.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryRemote: Equatable, Identifiable, Sendable {
    let name: String
    let url: String

    var id: String { name }
}
