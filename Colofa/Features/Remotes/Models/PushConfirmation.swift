////
//  PushConfirmation.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The open Push confirmation: which Branch is going where, and whether the user has deliberately
/// asked to replace what is already there.
///
/// It exists because a Push is the one ordinary command whose effect is on somebody else's copy of
/// the Repository. Showing the exact local Branch and the exact upstream before anything leaves is
/// what makes the destination something the user verified rather than something Colofa resolved
/// out of configuration nobody read.
///
/// The expected object is captured when this opens, not when it is confirmed. That is the whole
/// point of a lease: it describes the remote the user was looking at, so a remote that moves in
/// between is refused rather than overwritten.
nonisolated struct PushConfirmation: Equatable, Sendable {
    let branch: String
    let target: PushTarget

    /// The one address this Push writes to, resolved when the confirmation opened.
    ///
    /// Shown as well as remembered. The upstream `origin/main` names a remote, and a remote name
    /// is resolved to an address by Git at the moment the command runs — so the name alone cannot
    /// establish where the Push lands. Capturing the address is what lets the same question be
    /// asked again before anything is sent.
    let destination: PushDestination

    /// What the Branch pointed at when this opened.
    ///
    /// A Push sends whatever the Branch holds at the moment it runs, which for an ordinary Push is
    /// harmless: a remote refuses anything that is not a fast-forward. A Force Push with Lease has
    /// no such refusal on the local side — the lease describes the remote — so the history it
    /// would install is only the history the user agreed to for as long as this value still
    /// matches. `nil` on a Branch whose Commit Colofa could not read, which is the same state that
    /// leaves nothing to force with.
    let localObjectID: String?

    /// Off by default and never remembered. A normal Push is what pressing Push means; replacing
    /// the upstream's history is a separate thing the user asks for each time.
    var forcesWithLease = false

    init(
        branch: String,
        target: PushTarget,
        destination: PushDestination,
        localObjectID: String?
    ) {
        self.branch = branch
        self.target = target
        self.destination = destination
        self.localObjectID = localObjectID
    }

    /// Whether a lease can be taken at all.
    ///
    /// It cannot when nothing has ever been observed at the upstream, and Colofa offers no way
    /// around that: a force with no expected object is a naked force, which is the one thing this
    /// dialog exists to make impossible.
    var canForceWithLease: Bool {
        target.expectedObjectID != nil
    }

    /// The object the remote must still hold, or `nil` for an ordinary Push.
    var lease: String? {
        forcesWithLease ? target.expectedObjectID : nil
    }

    /// What the running command is doing, which is not the same sentence for the two of them.
    var work: PushProgress.Work {
        forcesWithLease ? .forcing : .pushing
    }

    var arguments: [String] {
        PushCommand.push(branch, to: target, lease: lease)
    }

    /// Whether this dialog still describes `repository`.
    ///
    /// A dialog outlives the reload that happens under it — the window becoming active is enough
    /// to cause one — so what it showed has to be checked against what is there now rather than
    /// assumed. A reload that changed nothing leaves every comparison equal, which is why this
    /// asks about the facts on screen instead of about the reload itself.
    ///
    /// The destination is deliberately not among them. A snapshot carries each remote's fetch URL,
    /// which is not the address a Push writes to, so the only honest check is a fresh read of the
    /// push address — and that is done once, immediately before the command runs.
    func describes(_ repository: RepositorySnapshot) -> Bool {
        guard case .branch(let current) = repository.head,
              current == branch,
              repository.upstream?.name == target.upstream else {
            return false
        }
        // Only a force is sensitive to the Branch itself moving. An ordinary Push that is no
        // longer a fast-forward is refused by the remote, so there is nothing here to protect.
        return !forcesWithLease || repository.headCommit?.objectID == localObjectID
    }
}
