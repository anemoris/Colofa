////
//  WorkspaceState+Failures.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// The one place a Repository failure is put on screen and taken off it again.
///
/// Every failure lands in the same slot, so a Repository that could not be opened, a command Git
/// refused, and the persistent details either of them can expand into never fight over the
/// window.
extension WorkspaceState {
    var isShowingRepositoryOpenError: Bool {
        get {
            if case .repositoryOpenAlert = repositoryFailure {
                true
            } else {
                false
            }
        }
        set {
            if !newValue {
                dismissRepositoryOpenError()
            }
        }
    }

    var isShowingRepositoryMutationError: Bool {
        get { repositoryFailure?.isMutationAlert == true }
        set {
            if !newValue {
                dismissRepositoryMutationError()
            }
        }
    }

    func chooseAnotherRepository() {
        repositoryFailure = nil
        isPresentingRepositoryPicker = true
    }

    func dismissRepositoryOpenError() {
        guard case .repositoryOpenAlert = repositoryFailure else {
            return
        }
        repositoryFailure = repositoryFailure?.expandedDetails
    }

    func dismissFailureDetails() {
        repositoryFailure = nil
    }

    func showRepositoryMutationErrorDetails() {
        guard repositoryFailure?.isMutationAlert == true,
              let expanded = repositoryFailure?.expandedDetails else {
            return
        }
        repositoryFailure = expanded
    }

    func dismissRepositoryMutationError() {
        guard repositoryFailure?.isMutationAlert == true else {
            return
        }
        repositoryFailure = nil
    }

    var repositoryFailureDetails: GitFailureDetails? {
        repositoryFailure.flatMap(\.details)
    }

    var repositoryFailureTitle: LocalizedStringResource? {
        repositoryFailure.flatMap(\.title)
    }

    var repositoryFailureMessage: LocalizedStringResource? {
        repositoryFailure.flatMap(\.message)
    }

    var canShowRepositoryFailureDetails: Bool {
        repositoryFailure?.canShowDetails == true
    }

    func presentRepositoryOpenError(_ error: RepositoryOpenError) {
        repositoryFailure = .repositoryOpenAlert(error)
    }

    func presentMutationError(
        _ error: RepositoryOpenError,
        title: LocalizedStringResource
    ) {
        repositoryFailure = .mutationAlert(error, title: title)
    }

    /// Puts one already-composed presentation on screen, for a caller that can explain its own
    /// refusal better than the shared command alert does.
    func presentFailure(_ presentation: RepositoryFailurePresentation) {
        repositoryFailure = presentation
    }
}
