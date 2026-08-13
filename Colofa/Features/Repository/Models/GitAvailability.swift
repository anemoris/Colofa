////
//  GitAvailability.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

enum GitAvailability: Equatable, Sendable {
    case available(URL)
    case unavailable
}
