////
//  DiffSplitRowTests.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Testing
@testable import Colofa

struct DiffSplitRowTests {
    @Test
    func pairsAReplacementAndRepeatsContextOnBothSides() {
        let rows = DiffSplitRow.rows(from: lines([
            (.context, "kept"),
            (.deletion, "old"),
            (.addition, "new"),
            (.context, "tail"),
        ]))

        #expect(rows.map { $0.old?.text } == ["kept", "old", "tail"])
        #expect(rows.map { $0.new?.text } == ["kept", "new", "tail"])
    }

    @Test
    func leavesTheShorterSideOfAnUnbalancedReplacementEmpty() {
        let rows = DiffSplitRow.rows(from: lines([
            (.deletion, "one"),
            (.addition, "1"),
            (.addition, "2"),
            (.addition, "3"),
        ]))

        #expect(rows.map { $0.old?.text } == ["one", nil, nil])
        #expect(rows.map { $0.new?.text } == ["1", "2", "3"])
    }

    @Test
    func startsANewReplacementWhenDeletionsFollowAdditions() {
        let rows = DiffSplitRow.rows(from: lines([
            (.deletion, "a"),
            (.addition, "A"),
            (.deletion, "b"),
            (.addition, "B"),
        ]))

        #expect(rows.map { $0.old?.text } == ["a", "b"])
        #expect(rows.map { $0.new?.text } == ["A", "B"])
    }

    @Test
    func keepsTheNoNewlineMarkerOnTheSideOfTheLineItDocuments() {
        let deletionSide = DiffSplitRow.rows(from: lines([
            (.deletion, "old"),
            (.noNewlineMarker, ""),
            (.addition, "new"),
        ]))
        let additionSide = DiffSplitRow.rows(from: lines([
            (.deletion, "old"),
            (.addition, "new"),
            (.noNewlineMarker, ""),
        ]))

        #expect(deletionSide.map { $0.old?.kind } == [.deletion, .noNewlineMarker])
        #expect(deletionSide.map { $0.new?.kind } == [.addition, nil])
        #expect(additionSide.map { $0.old?.kind } == [.deletion, nil])
        #expect(additionSide.map { $0.new?.kind } == [.addition, .noNewlineMarker])
    }

    @Test
    func numbersRowsFromZeroWithinTheHunk() {
        let rows = DiffSplitRow.rows(from: lines([
            (.context, "one"),
            (.context, "two"),
        ]))

        #expect(rows.map(\.id) == [0, 1])
        #expect(DiffSplitRow.rows(from: []).isEmpty)
    }

    @Test
    func aHunkCarriesBothLayoutsOfTheSameLines() {
        let hunk = DiffHunk(
            id: 0,
            oldStart: 1,
            oldCount: 2,
            newStart: 1,
            newCount: 2,
            lines: lines([(.deletion, "old"), (.addition, "new")])
        )

        #expect(hunk.lines.count == 2)
        #expect(hunk.splitRows == DiffSplitRow.rows(from: hunk.lines))
        #expect(hunk.stats == DiffStats(additions: 1, deletions: 1))
    }

    private func lines(_ values: [(DiffLine.Kind, String)]) -> [DiffLine] {
        values.enumerated().map { index, value in
            DiffLine(
                id: index,
                kind: value.0,
                oldNumber: value.0 == .addition ? nil : index + 1,
                newNumber: value.0 == .deletion ? nil : index + 1,
                text: value.1
            )
        }
    }
}
