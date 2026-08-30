////
//  WorkspaceState+PushDialogs.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The two questions a Push can have open, and the one way each of them closes without sending
/// anything.
///
/// Kept apart from the commands they precede because they are the Store's published state rather
/// than its work: a window binds to them, and nothing here contacts a remote.
extension WorkspaceState {
    var isConfirmingPush: Bool {
        get {
            if case .confirmation = pushDialog {
                true
            } else {
                false
            }
        }
        set {
            if !newValue {
                cancelPushConfirmation()
            }
        }
    }

    var isChoosingPublishRemote: Bool {
        get {
            if case .publishRemote = pushDialog {
                true
            } else {
                false
            }
        }
        set {
            if !newValue {
                cancelPublishRemote()
            }
        }
    }

    func cancelPushConfirmation() {
        guard case .confirmation = pushDialog else {
            return
        }
        pushDialog = nil
    }

    func cancelPublishRemote() {
        guard case .publishRemote = pushDialog else {
            return
        }
        pushDialog = nil
    }

    /// Closes an open dialog that has stopped describing the Repository, and says so.
    ///
    /// Nothing about a Push confirmation is re-read once it opens — that is what makes the lease
    /// mean something — so the dialog is dismissed rather than quietly updated underneath the
    /// user. The alert exists because a sheet that vanishes on its own is otherwise indistinguish-
    /// able from one the user dismissed by accident.
    ///
    /// Not private: `publishRepository` in WorkspaceState.swift calls it on every reload of the
    /// same Repository, and Swift keeps `private` within one file.
    func reconcilePushDialog(against repository: RepositorySnapshot) {
        guard let pushDialog, !pushDialog.describes(repository) else {
            return
        }
        self.pushDialog = nil
        isShowingStalePushAlert = true
    }
}
