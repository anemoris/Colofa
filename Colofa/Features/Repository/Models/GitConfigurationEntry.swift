////
//  GitConfigurationEntry.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

struct GitConfigurationEntry: Equatable, Hashable, Sendable {
    let key: GitConfigurationKey
    let value: String
    let scope: GitConfigurationScope
    let origin: GitConfigurationOrigin
}
