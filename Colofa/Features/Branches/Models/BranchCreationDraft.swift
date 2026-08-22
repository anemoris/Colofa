////
//  BranchCreationDraft.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The one New Branch dialog, whichever entry point opened it.
///
/// The start point is fixed when the dialog opens and never editable: the toolbar starts at HEAD
/// and History starts at the selected Commit, and a dialog that let either be retyped would stop
/// showing where the branch actually begins.
nonisolated struct BranchCreationDraft: Equatable, Sendable {
    let startPoint: BranchStartPoint

    private var storedName = ""

    /// The name, exactly as the field shows it and exactly as Git is asked to create it.
    ///
    /// Surrounding whitespace is dropped on the way in rather than refused: Git accepts no
    /// whitespace in a branch name at all, so a pasted name with a trailing newline would
    /// otherwise fail validation for a character the user cannot see. Dropping it here rather
    /// than at the point of use is what keeps the field honest — the dialog never creates a
    /// branch under a name other than the one it showed, which is the same reason a name Git
    /// would rewrite is refused outright.
    var name: String {
        get { storedName }
        set {
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized != storedName else {
                return
            }
            storedName = normalized
            // A refusal describes the name that caused it, so editing that name retires it.
            failure = nil
        }
    }

    /// Enabled by default, because creating a branch to work on it is the ordinary case, and
    /// optional, because creating a ref without moving HEAD is the other one.
    var checksOutNewBranch = true

    /// The last name real Git was asked about, and the answer it gave.
    private(set) var checkedName: String?
    private(set) var isCheckedNameValid = false

    /// Why Git refused the last attempt, or `nil` when nothing stands against the current name.
    private(set) var failure: BranchCreationFailure?

    init(startPoint: BranchStartPoint) {
        self.startPoint = startPoint
    }

    /// What Git answered about the name currently typed, or `nil` when that answer is about an
    /// earlier one.
    var formatValidity: Bool? {
        checkedName == name ? isCheckedNameValid : nil
    }

    mutating func recordFormatCheck(of name: String, isValid: Bool) {
        checkedName = name
        isCheckedNameValid = isValid
    }

    mutating func recordFailure(_ failure: BranchCreationFailure) {
        self.failure = failure
    }

    mutating func clearFailure() {
        failure = nil
    }

    /// The exact command Git runs.
    ///
    /// Creating without Checkout uses `git branch`, which writes one ref and leaves HEAD and the
    /// working tree alone. Creating with Checkout uses a single `git switch --create`, which
    /// either creates the branch and moves to it or does neither — so a Checkout Git refuses
    /// never leaves a branch behind that the user did not ask for on its own.
    var arguments: [String] {
        checksOutNewBranch
            ? ["switch", "--create", name, startPoint.revision]
            : ["branch", "--", name, startPoint.revision]
    }
}
