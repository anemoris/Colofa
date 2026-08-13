////
//  RepositoryUpstream.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct RepositoryUpstream: Equatable, Sendable {
    let name: String
    let ahead: Int
    let behind: Int
}
