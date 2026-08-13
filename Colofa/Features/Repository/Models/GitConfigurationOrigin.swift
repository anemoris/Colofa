////
//  GitConfigurationOrigin.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

struct GitConfigurationOrigin: Equatable, Hashable, Sendable {
    let rawValue: String

    var location: String {
        guard rawValue.hasPrefix("file:") else {
            return rawValue
        }
        return String(rawValue.dropFirst("file:".count))
    }
}
