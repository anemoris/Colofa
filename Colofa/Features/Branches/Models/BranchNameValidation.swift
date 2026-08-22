////
//  BranchNameValidation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What Git says about the branch name the user is typing.
///
/// The format answer comes from `git check-ref-format --branch`, which is the same check
/// `git branch` applies, so Colofa accepts exactly the names Git accepts rather than reproducing
/// its rules. Existence is answered from the Refs the Repository already reported, because that
/// is a fact Colofa holds and a round trip would only delay.
nonisolated enum BranchNameValidation: Equatable, Sendable {
    /// Nothing typed yet, which is not a mistake to report.
    case empty
    /// Real Git has not answered about this name yet.
    case checking
    case valid
    case invalidFormat
    case alreadyExists

    /// Names beginning with a hyphen never reach Git's option parser.
    ///
    /// `git branch` refuses them outright — a branch name is not allowed to look like an option —
    /// so refusing them here reproduces Git's own answer instead of handing Git a user string it
    /// would read as a flag.
    static let optionPrefix = "-"

    /// - Parameter isFormatValid: What real Git answered about this exact name, or `nil` while
    ///   nothing has been asked or the answer belongs to an earlier name.
    static func evaluate(
        name: String,
        existingLocalBranches: [String],
        isFormatValid: Bool?
    ) -> Self {
        guard !name.isEmpty else {
            return .empty
        }
        guard !name.hasPrefix(optionPrefix) else {
            return .invalidFormat
        }
        guard !existingLocalBranches.contains(name) else {
            return .alreadyExists
        }
        switch isFormatValid {
        case nil: return .checking
        case false?: return .invalidFormat
        case true?: return .valid
        }
    }

    /// Whether Create may run. A name Git has not answered about yet is not one Colofa creates.
    var allowsCreation: Bool { self == .valid }

    /// The actionable reason, or `nil` when there is nothing to say yet.
    var message: LocalizedStringResource? {
        switch self {
        case .empty, .checking, .valid: nil
        case .invalidFormat: .branchNameInvalid
        case .alreadyExists: .branchNameAlreadyExists
        }
    }
}

nonisolated struct BranchNameValidationRequest: Equatable, Sendable {
    let repositoryURL: URL
    let name: String
}
