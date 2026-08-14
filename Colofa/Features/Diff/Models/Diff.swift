////
//  Diff.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A patch Colofa read in full and parsed.
///
/// It holds several files because the same representation serves a Commit or a Stash, where one
/// patch covers everything that changed; a working-tree selection normally yields one.
nonisolated struct Diff: Equatable, Sendable {
    let files: [DiffFile]
    let measurement: DiffMeasurement
    let stats: DiffStats

    init(files: [DiffFile], measurement: DiffMeasurement) {
        self.files = files
        self.measurement = measurement
        stats = files.reduce(.zero) { $0 + $1.stats }
    }
}
