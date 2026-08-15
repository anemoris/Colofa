////
//  DiffLoadRequest.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

nonisolated struct DiffLoadRequest: Equatable, Sendable {
    let source: DiffSource
    let repositoryURL: URL
    let limits: DiffLimits
    /// Whether the user already accepted the cost of a patch above an automatic limit. It raises
    /// the bound reading stops at; it never removes one.
    let isConfirmed: Bool

    init(
        source: DiffSource,
        repositoryURL: URL,
        limits: DiffLimits = .standard,
        isConfirmed: Bool = false
    ) {
        self.source = source
        self.repositoryURL = repositoryURL
        self.limits = limits
        self.isConfirmed = isConfirmed
    }
}

nonisolated enum DiffLoadResult: Equatable, Sendable {
    case diff(Diff)
    /// Above an automatic limit but within both hard limits, so rendering it is offered.
    case confirmationRequired(DiffSummary)
    /// Beyond a hard limit. Only what `DiffSummary` holds was ever read.
    case beyondHardLimit(DiffSummary)
}
