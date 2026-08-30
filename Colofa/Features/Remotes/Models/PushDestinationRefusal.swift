////
//  PushDestinationRefusal.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Why Colofa will not push to a remote at all, decided before anything leaves and reported
/// instead of a Push.
///
/// Every case here is a configuration Colofa cannot describe honestly in one confirmation. The
/// promise the Push confirmation makes is that exactly the Ref it shows travels to exactly the
/// destination it shows; a remote that resolves to somewhere else, or to more than one somewhere,
/// breaks that promise in a way no wording can repair. Refusing is deliberate: none of these can
/// be undone as a whole once Git has started writing.
nonisolated enum PushDestinationRefusal: Error, Equatable, Sendable {

    /// The remote is `.`, which is Git's own name for the Repository the command already runs in.
    /// A Push to it rewrites a local Branch rather than sending one anywhere, and a Force Push
    /// with Lease to it replaces local history the confirmation described as an upstream.
    ///
    /// It is not exotic: `git branch --track <new> <local>` configures it, and Git then reports
    /// the local Branch as that Branch's upstream like any other.
    case localRepository(remote: String)

    /// The remote has more than one push address. One `git push` writes to all of them in turn,
    /// so a confirmation naming one destination would be naming a fraction of what happens — and
    /// a Force Push with Lease that is accepted at one address and refused at another leaves a
    /// partial rewrite that no single command can roll back.
    case severalDestinations(remote: String, [PushDestination])

    /// The remote's address stopped being the one the confirmation captured, between opening the
    /// confirmation and pressing its button. Nothing was sent.
    case changed(remote: String)

    var title: LocalizedStringResource {
        switch self {
        case .localRepository: .pushDestinationLocalTitle
        case .severalDestinations: .pushDestinationSeveralTitle
        case .changed: .pushDestinationChangedTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .localRepository(let remote):
            .pushDestinationLocalDescription(remote)
        case .severalDestinations(let remote, let destinations):
            .pushDestinationSeveralDescription(remote, Self.listing(destinations))
        case .changed(let remote):
            .pushDestinationChangedDescription(remote)
        }
    }

    /// The addresses one Push would have written to, one per line and with every password already
    /// removed. Naming them is the point: the user has to be able to find the configuration this
    /// refusal is about.
    private static func listing(_ destinations: [PushDestination]) -> String {
        destinations.map(\.display).joined(separator: "\n")
    }
}
