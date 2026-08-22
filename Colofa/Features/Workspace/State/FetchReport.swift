////
//  FetchReport.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// What one Fetch did, together with the alert it raises.
///
/// The two travel as one because both are produced inside the cancellable task. Working out what
/// to say about a refused Fetch Tags means contacting the remote a second time, and anything that
/// contacts a remote has to remain something the user can stop.
struct FetchReport: Sendable {
    let outcome: FetchOutcome

    /// The alert to raise once the Repository has been reloaded, or `nil` when this Fetch raises
    /// none.
    let failure: RepositoryFailurePresentation?
}
