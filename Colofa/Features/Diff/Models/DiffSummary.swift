////
//  DiffSummary.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What Colofa knows about a patch it did not render.
///
/// Git counts changed lines without writing the patch out, so these numbers are exact even when
/// the patch itself was never read to the end.
nonisolated struct DiffSummary: Equatable, Sendable {
    let files: [DiffFileSummary]
    let measurement: DiffMeasurement
    let stats: DiffStats

    init(files: [DiffFileSummary], measurement: DiffMeasurement) {
        self.files = files
        self.measurement = measurement
        stats = files.reduce(.zero) { $0 + ($1.stats ?? .zero) }
    }
}

/// One path in a patch Colofa did not render. `stats` is absent for a binary change, where Git
/// reports no line counts rather than reporting zero.
nonisolated struct DiffFileSummary: Equatable, Identifiable, Sendable {
    let oldPath: String?
    let newPath: String
    let stats: DiffStats?

    var id: String { "\(oldPath ?? "")\u{0}\(newPath)" }

    var isBinary: Bool { stats == nil }

    var isRenamed: Bool {
        guard let oldPath else {
            return false
        }
        return oldPath != newPath
    }
}
