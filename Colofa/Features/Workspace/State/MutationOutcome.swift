////
//  MutationOutcome.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

extension WorkspaceState {
    /// What one mutating command did, for a caller that answers a failure with more than the
    /// shared alert.
    ///
    /// Nested rather than free-standing: it is the Store's own answer about the Store's own
    /// command, and it says nothing outside that.
    enum MutationOutcome: Equatable, Sendable {
        case succeeded
        /// Nothing ran: there is no Repository, or another command already holds it.
        case unavailable
        case failed(RepositoryOpenError)
    }
}
