////
//  GitOutputParsingError.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

struct GitOutputParsingError: LocalizedError, Equatable, Sendable {
    var errorDescription: String? {
        String(localized: .gitOutputParsingFailed)
    }
}
