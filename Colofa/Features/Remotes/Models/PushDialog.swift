////
//  PushDialog.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The question a Push has to ask before anything leaves for a remote.
///
/// One value rather than two, because at most one of them is ever open: a Branch either has an
/// upstream to confirm or has nowhere to go yet, and holding both separately would let two sheets
/// disagree about which one the window belongs to.
nonisolated enum PushDialog: Equatable, Sendable {

    /// A Branch with an upstream, showing exactly where it is going before it goes.
    case confirmation(PushConfirmation)

    /// A Branch nobody has pushed yet, in a Repository whose configuration named no remote and
    /// which has more than one to choose from.
    case publishRemote(PublishRemoteSelection)

    /// Whether whichever question is open still describes `repository`.
    func describes(_ repository: RepositorySnapshot) -> Bool {
        switch self {
        case .confirmation(let confirmation): confirmation.describes(repository)
        case .publishRemote(let selection): selection.describes(repository)
        }
    }

    var confirmation: PushConfirmation? {
        get {
            if case .confirmation(let confirmation) = self {
                confirmation
            } else {
                nil
            }
        }
        set {
            if let newValue {
                self = .confirmation(newValue)
            }
        }
    }

    var publishRemote: PublishRemoteSelection? {
        get {
            if case .publishRemote(let selection) = self {
                selection
            } else {
                nil
            }
        }
        set {
            if let newValue {
                self = .publishRemote(newValue)
            }
        }
    }
}
