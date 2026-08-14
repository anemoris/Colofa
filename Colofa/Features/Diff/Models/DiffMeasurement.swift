////
//  DiffMeasurement.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// How large a patch turned out to be while it was being read.
///
/// `isComplete` is what keeps the numbers honest: reading stops the moment a limit is established,
/// so a patch Colofa refused was never measured to the end and its counts are lower bounds.
nonisolated struct DiffMeasurement: Equatable, Sendable {
    let byteCount: Int
    let lineCount: Int
    let isComplete: Bool
}
