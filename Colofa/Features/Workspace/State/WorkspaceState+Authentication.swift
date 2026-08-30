////
//  WorkspaceState+Authentication.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// Answering the questions Git and OpenSSH ask while a command of Colofa's is running.
///
/// Colofa is the last thing asked, never the first. A configured credential helper, macOS
/// Keychain integration, `ssh-agent`, and the user's OpenSSH configuration all answer first and
/// are left exactly as configured; a prompt appears here only once none of them answered.
///
/// What is typed lives here for as long as the prompt is on screen and nowhere else. It is handed
/// to the process that asked and cleared in the same step, and whether it survives afterwards is
/// decided by the helper or agent that owns it — Colofa keeps no credential store of its own.
extension WorkspaceState {

    // MARK: - Answering

    /// Who answers the questions one command asks.
    ///
    /// Handed to the command rather than reached for by it: the command runs off the main actor,
    /// and this is the one door back onto it.
    var authenticationResponder: AuthenticationResponder {
        AuthenticationResponder { [weak self] request in
            guard let self else {
                return .cancelled
            }
            return await ask(request)
        }
    }

    var isPresentingAuthenticationRequest: Bool {
        get { authenticationRequest != nil }
        set {
            if !newValue {
                cancelAuthentication()
            }
        }
    }

    /// Whether what has been typed can be submitted.
    ///
    /// A passphrase or password may legitimately be anything, including nothing, so only a
    /// username is required to be non-empty: Git rejects an empty one itself, and asking again is
    /// worse than not accepting it here.
    var canSubmitAuthentication: Bool {
        guard let request = authenticationRequest, request.isAnswerable else {
            return false
        }
        guard request.kind == .username else {
            return true
        }
        return !authenticationAnswer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Hands what was typed to the process that asked for it.
    ///
    /// A host key question is answered with OpenSSH's own word rather than with anything typed:
    /// confirming a fingerprint is agreement, not entry.
    func submitAuthentication() {
        guard let request = authenticationRequest, canSubmitAuthentication else {
            return
        }
        let answer = request.kind.isConfirmation
            ? AuthenticationRequestKind.confirmation
            : authenticationAnswer
        endAuthentication(with: .answer(answer))
    }

    /// Refuses the question and stops the operation that asked it.
    ///
    /// Both halves are the same decision. A refused question leaves Git with no credential and no
    /// terminal to ask on, so it would end anyway — ending it here means the user sees the Cancel
    /// they pressed rather than the failure it would have turned into.
    ///
    /// A Fetch, the Fetch half of a Pull, and a Publish or Push are what get stopped, because
    /// they are the commands that contact a remote, and only such a command can be asked for a
    /// secret. Each call is a no-op unless that command is the one running.
    func cancelAuthentication() {
        guard authenticationRequest != nil || pendingAuthentication != nil else {
            return
        }
        // Stopped before the refusal is handed back, so the command that resumes already knows
        // it was cancelled and reports the Cancel rather than the failure it would have become.
        cancelFetch()
        cancelPull()
        cancelPush()
        endAuthentication(with: .cancelled)
    }

    // MARK: - Presenting

    private func ask(_ request: AuthenticationRequest) async -> AuthenticationResponse {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                present(request, answering: continuation)
            }
        } onCancel: {
            // The operation ended underneath the prompt — the user stopped it, or something else
            // did. Whatever is on screen is no longer a question anybody is waiting for.
            Task { @MainActor in
                self.endAuthentication(of: request.id, with: .cancelled)
            }
        }
    }

    /// Ends the prompt only when it is still the one `id` names.
    ///
    /// A question that was refused rather than shown belongs to no prompt, so the command it
    /// belonged to ending must not take somebody else's prompt down with it.
    private func endAuthentication(of id: UUID, with response: AuthenticationResponse) {
        guard authenticationRequest?.id == id else {
            return
        }
        endAuthentication(with: response)
    }

    private func present(
        _ request: AuthenticationRequest,
        answering continuation: CheckedContinuation<AuthenticationResponse, Never>
    ) {
        // A question that arrives for an operation already being stopped, or while another one is
        // still open, is refused rather than shown. An answer belongs to the prompt it was typed
        // into, and a second prompt over the first would make it impossible to say which.
        guard !Task.isCancelled, authenticationRequest == nil, pendingAuthentication == nil else {
            continuation.resume(returning: .cancelled)
            return
        }
        authenticationRequest = request
        authenticationAnswer = ""
        pendingAuthentication = continuation
    }

    /// Resumes the waiting command exactly once and takes the prompt off screen, clearing what
    /// was typed in the same step.
    private func endAuthentication(with response: AuthenticationResponse) {
        let continuation = pendingAuthentication
        pendingAuthentication = nil
        authenticationRequest = nil
        authenticationAnswer = ""
        continuation?.resume(returning: response)
    }
}
