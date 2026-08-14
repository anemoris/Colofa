////
//  DiffLimits.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two size boundaries a patch is measured against while it is being read.
///
/// Both are pairs, and a patch has to satisfy *both* halves of a pair to stay below it: a
/// one-line patch holding a 3 MiB minified bundle is as expensive to render as a 30,000-line one.
///
/// Injectable so tests can exercise the same decisions against small, cheap patches; `standard`
/// carries the real values.
nonisolated struct DiffLimits: Equatable, Sendable {
    /// The largest patch Colofa renders without asking.
    let automaticByteCount: Int
    let automaticLineCount: Int

    /// The largest patch Colofa renders at all. Beyond it only stats and metadata are shown.
    let hardByteCount: Int
    let hardLineCount: Int

    static let standard = Self(
        automaticByteCount: 2 * 1_024 * 1_024,
        automaticLineCount: 20_000,
        hardByteCount: 10 * 1_024 * 1_024,
        hardLineCount: 100_000
    )

    var automaticBounds: GitOutputBounds {
        GitOutputBounds(byteCount: automaticByteCount, lineCount: automaticLineCount)
    }

    var hardBounds: GitOutputBounds {
        GitOutputBounds(byteCount: hardByteCount, lineCount: hardLineCount)
    }
}
