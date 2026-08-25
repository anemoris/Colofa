////
//  AuthenticationRequestKind.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Which question Git or OpenSSH is asking, and therefore how Colofa may ask it.
///
/// Only the question is modelled here. The answer never is: it travels from the field to the
/// process that asked and is dropped, so no case carries one and nothing derived from one is
/// stored.
nonisolated enum AuthenticationRequestKind: Equatable, Sendable {

    /// The account name an HTTPS remote asked for, which is the one answer that is not a secret.
    case username

    /// The password or personal access token an HTTPS remote asked for.
    case password

    /// The passphrase that decrypts one SSH private key.
    case keyPassphrase

    /// A host OpenSSH has never seen, with the fingerprint it read from that host — or `nil`
    /// when the question arrived without one, which is the case where nothing may be confirmed.
    case newHostKey(fingerprint: String?)

    /// A host whose key no longer matches the one OpenSSH recorded. Colofa answers this itself,
    /// and always with no.
    case changedHostKey

    /// A question Colofa could not classify. It is asked exactly as it arrived and answered
    /// secretly, because an unrecognized question is more likely to be about a secret than not.
    case unrecognized

    /// Whether the answer must never be shown while it is typed.
    var isSecret: Bool {
        switch self {
        case .password, .keyPassphrase, .unrecognized: true
        case .username, .newHostKey, .changedHostKey: false
        }
    }

    /// Whether this is a yes-or-no question rather than something to type.
    var isConfirmation: Bool {
        switch self {
        case .newHostKey: true
        case .username, .password, .keyPassphrase, .changedHostKey, .unrecognized: false
        }
    }

    /// Whether Colofa refuses this question outright, without offering the user an override.
    ///
    /// A host key that changed is the one question a Git client must not put to the user as a
    /// choice: the answer that continues is also the answer that accepts a machine-in-the-middle,
    /// and OpenSSH already recorded a different key for that host.
    var isRefused: Bool {
        self == .changedHostKey
    }

    /// What OpenSSH accepts as agreement, which is the literal word rather than anything
    /// localized: this reaches `ssh`, not the user.
    static let confirmation = "yes"

    var title: LocalizedStringResource {
        switch self {
        case .username: .authenticationUsernameTitle
        case .password: .authenticationPasswordTitle
        case .keyPassphrase: .authenticationPassphraseTitle
        case .newHostKey: .authenticationHostKeyTitle
        case .changedHostKey: .authenticationHostKeyChangedTitle
        case .unrecognized: .authenticationRequestTitle
        }
    }

    /// What the prompt is for, in Colofa's words. Git's own question is shown alongside it, so
    /// this explains rather than replaces it.
    var message: LocalizedStringResource {
        switch self {
        case .username: .authenticationUsernameMessage
        case .password: .authenticationPasswordMessage
        case .keyPassphrase: .authenticationPassphraseMessage
        case .newHostKey: .authenticationHostKeyMessage
        case .changedHostKey: .authenticationHostKeyChangedMessage
        case .unrecognized: .authenticationRequestMessage
        }
    }

    /// What the thing being asked about is called: an HTTPS remote, an SSH key, the host of an
    /// SSH connection, or — for a question Colofa did not recognize — simply what was asked.
    var subjectLabel: LocalizedStringResource {
        switch self {
        case .username, .password: .remote
        case .keyPassphrase: .authenticationKey
        case .newHostKey, .changedHostKey: .authenticationHost
        case .unrecognized: .authenticationSubject
        }
    }

    /// What the field is labelled, which VoiceOver reads in place of a placeholder.
    var fieldLabel: LocalizedStringResource {
        switch self {
        case .username: .authenticationUsernameField
        case .password: .authenticationPasswordField
        case .keyPassphrase: .authenticationPassphraseField
        case .newHostKey, .changedHostKey, .unrecognized: .authenticationAnswerField
        }
    }

    /// What the button that answers this question is called.
    var submitTitle: LocalizedStringResource {
        switch self {
        case .newHostKey: .authenticationTrustHost
        case .username, .password, .keyPassphrase, .changedHostKey, .unrecognized: .authenticationContinue
        }
    }
}
