////
//  PushRejection.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why a remote refused an update, read out of the one part of Git's answer that is written for a
/// machine.
///
/// A Push that failed and a Push that was refused are different events. A remote nobody could
/// reach, a key nobody trusted, and an upstream holding work this Branch does not have all end as
/// one failed `git push`, and only the last of them is something the user can act on by
/// integrating first.
///
/// `--porcelain` is what makes the difference legible. Git reports each Ref's fate as
/// `<flag>\t<from>:<to>\t<summary> (<reason>)`, and those summaries and reasons are fixed strings
/// rather than translated advice — so this reads Git's report instead of scraping a hint that
/// changes with the user's language.
nonisolated enum PushRejection: Equatable, Sendable {

    /// The upstream holds Commits the Branch does not, so accepting the update would drop them.
    case nonFastForward

    /// The remote moved after the Push was confirmed, so the lease refused it. The Push protected
    /// exactly the work it was taken out to protect.
    case staleLease

    /// The remote itself declined — a Hook, a protected branch, a permission. Nothing about the
    /// local Branch explains it, so only the remote's own words can.
    case remoteRefused

    /// What `output` says the remote decided, or `nil` when it says nothing about a refusal at
    /// all — which is every failure that never reached the remote's answer.
    static func detect(in output: String) -> Self? {
        // A stale lease is checked first because it is also a rejection Git reports on the same
        // line; the general answer would hide the one the user acted on.
        if output.contains("(stale info)") {
            return .staleLease
        }
        // Git reports the same refusal as either of these: `fetch first` when it knows the remote
        // holds something newer, and `non-fast-forward` when the update simply is not one.
        if output.contains("(fetch first)") || output.contains("(non-fast-forward)") {
            return .nonFastForward
        }
        return output.contains("[remote rejected]") ? .remoteRefused : nil
    }

    var title: LocalizedStringResource {
        switch self {
        case .nonFastForward: .pushRejectedTitle
        case .staleLease: .pushLeaseRefusedTitle
        case .remoteRefused: .pushRemoteRefusedTitle
        }
    }

    /// What happened and what to do about it, naming both Refs.
    ///
    /// Force Push is deliberately never suggested. A Branch whose upstream moved is one to
    /// integrate, and recommending the option that discards the other side's work would be
    /// recommending the thing this refusal just prevented.
    func message(branch: String, upstream: String) -> LocalizedStringResource {
        switch self {
        case .nonFastForward: .pushRejectedDescription(branch, upstream)
        case .staleLease: .pushLeaseRefusedDescription(upstream)
        case .remoteRefused: .pushRemoteRefusedDescription(upstream)
        }
    }
}
