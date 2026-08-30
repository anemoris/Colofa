////
//  PushProgress.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A Publish or Push that is running right now, and which of the two it is.
///
/// Unlike a Pull, this has no second half: everything a Push does happens out at the remote, so
/// it stays stoppable for as long as it runs. What is left afterwards is Colofa's own reload,
/// which is a local read and not something to interrupt.
nonisolated struct PushProgress: Equatable, Sendable {

    /// What the running command is for, which is what the user is told while they wait.
    enum Work: Equatable, Sendable {

        /// Creating the Branch on a remote for the first time.
        case publishing

        /// Sending the Branch to its established upstream.
        case pushing

        /// Replacing the upstream's history, with a lease standing behind it.
        case forcing
    }

    /// Where it is going, as the user reads it: a remote's name for a Publish, and the upstream
    /// for a Push.
    let target: String

    let work: Work

    var description: LocalizedStringResource {
        switch work {
        case .publishing: .pushPublishingTo(target)
        case .pushing: .pushSendingTo(target)
        case .forcing: .pushForcingTo(target)
        }
    }
}
