////
//  RepositoryChangeTintTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI
import Testing
@testable import Colofa

/// The color a row in the Changes list carries.
///
/// The letter is what states the kind; the tint only repeats it, so these assertions guard the
/// convention rather than the meaning. A kind that stopped matching its tint would still be
/// readable, but it would read as a different kind at a glance.
struct RepositoryChangeTintTests {
    @Test
    func aStagedNewFileAndAnUntrackedOneTintApart() {
        #expect(RepositoryChangeKind.added.tint == .green)
        #expect(RepositoryChangeKind.untracked.tint == .red)
    }

    @Test
    func everyEditOfATrackedPathTintsTheSame() {
        #expect(RepositoryChangeKind.modified.tint == .blue)
        #expect(RepositoryChangeKind.renamed(from: "old.txt").tint == .blue)
        #expect(RepositoryChangeKind.typeChanged.tint == .blue)
    }

    @Test
    func aDeletedPathRecedes() {
        #expect(RepositoryChangeKind.deleted.tint == .secondary)
    }

    /// A Conflict shares Untracked's red because both stop a Commit until the user acts. `U` and
    /// `?` are what tell them apart, which is what keeps the pair legible without the color.
    @Test
    func aConflictTintsAsSomethingToActOn() {
        #expect(RepositoryChangeKind.conflict.tint == .red)
    }
}
