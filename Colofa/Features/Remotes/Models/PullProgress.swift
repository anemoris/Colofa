////
//  PullProgress.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// A Pull that is running right now, and which of its two halves it is in.
///
/// The half matters to the user, not just to Colofa: contacting a remote has no duration Colofa
/// can promise, so it stays stoppable for as long as it runs, while the fast-forward that follows
/// is a short local command that must not be interrupted halfway. Only the first half offers a
/// way out, and this is what the toolbar reads to decide.
nonisolated struct PullProgress: Equatable, Sendable {

    /// Which half of the Pull is running.
    enum Phase: Equatable, Sendable {
        case contactingRemote
        case integrating
    }

    /// The upstream being pulled from, which is what the Pull is about.
    let upstream: String

    let phase: Phase

    /// Whether stopping it is something Colofa can honestly offer.
    var isCancellable: Bool {
        phase == .contactingRemote
    }

    var description: LocalizedStringResource {
        switch phase {
        case .contactingRemote: .pullFetchingUpstream(upstream)
        case .integrating: .pullIntegratingUpstream(upstream)
        }
    }
}
