////
//  AuthenticationPromptParser.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// Reads one AskPass question and decides which question it is.
///
/// Git and OpenSSH hand their AskPass program a single line — or, for a host key, several — and
/// nothing else. There is no machine-readable form of these prompts, so the English text is what
/// there is to read. Every rule below therefore has a fallback rather than a requirement: an
/// unclassified question is still asked, and is asked secretly.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation while the AskPass
/// bridge reads prompts off a socket.
nonisolated enum AuthenticationPromptParser {

    /// The question `prompt` is asking, and whom it is about.
    static func request(for prompt: String) -> AuthenticationRequest {
        let kind = kind(of: prompt)
        return AuthenticationRequest(
            kind: kind,
            subject: subject(of: prompt, asking: kind),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func kind(of prompt: String) -> AuthenticationRequestKind {
        // Checked before the new-host question, because a changed key's warning also ends with
        // the words that offer to continue. Reading them in the other order would turn the one
        // question Colofa refuses into the one it asks.
        if isChangedHostKey(prompt) {
            return .changedHostKey
        }
        if isHostKeyConfirmation(prompt) {
            return .newHostKey(fingerprint: fingerprint(in: prompt))
        }
        if prompt.contains("passphrase") || prompt.contains("Passphrase") {
            return .keyPassphrase
        }
        if prompt.contains("Username") {
            return .username
        }
        if prompt.contains("Password") || prompt.contains("password") {
            return .password
        }
        return .unrecognized
    }

    private static func isChangedHostKey(_ prompt: String) -> Bool {
        prompt.contains("HOST IDENTIFICATION HAS CHANGED")
            || prompt.contains("host key has just been changed")
            || (prompt.contains("host key for") && prompt.contains("has changed"))
    }

    private static func isHostKeyConfirmation(_ prompt: String) -> Bool {
        prompt.contains("authenticity of host") || prompt.contains("continue connecting")
    }

    /// The fingerprint OpenSSH read from the host, or `nil` when the question carried none.
    ///
    /// Only the value OpenSSH printed is returned. Colofa never derives, shortens, or reformats
    /// it: the user compares it against what their provider published, and a fingerprint Colofa
    /// rewrote is no longer that value.
    private static func fingerprint(in prompt: String) -> String? {
        let marker = "fingerprint is "
        guard let line = prompt
            .split(whereSeparator: \.isNewline)
            .first(where: { $0.contains(marker) }),
            let range = line.range(of: marker) else {
            return nil
        }
        let value = line[range.upperBound...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return value.isEmpty ? nil : value
    }

    private static func subject(
        of prompt: String,
        asking kind: AuthenticationRequestKind
    ) -> String? {
        switch kind {
        case .newHostKey, .changedHostKey:
            host(in: prompt)
        case .username, .password, .keyPassphrase, .unrecognized:
            quoted(in: prompt) ?? trailingSubject(in: prompt)
        }
    }

    /// The host name without the address OpenSSH prints beside it, which is the part the user
    /// recognizes.
    private static func host(in prompt: String) -> String? {
        guard let quoted = quoted(in: prompt) else {
            return nil
        }
        guard let address = quoted.range(of: " (") else {
            return quoted
        }
        return String(quoted[quoted.startIndex..<address.lowerBound])
    }

    /// What the question named between quotes, which is how Git and OpenSSH both write a remote
    /// URL, a host, and a key path.
    ///
    /// Either quotation mark, because they do not agree on one: Git writes a remote URL between
    /// single quotes and OpenSSH writes the key it is asking about between double ones. Reading
    /// only Git's would leave the marks themselves inside the name shown to the user.
    private static func quoted(in prompt: String) -> String? {
        guard let start = prompt.firstIndex(where: { $0 == "'" || $0 == "\"" }) else {
            return nil
        }
        let mark = prompt[start]
        let afterStart = prompt.index(after: start)
        guard let end = prompt[afterStart...].firstIndex(of: mark), afterStart < end else {
            return nil
        }
        return String(prompt[afterStart..<end])
    }

    /// What an unquoted question named after its last `for`, which is how `ssh-add` writes a key
    /// path.
    private static func trailingSubject(in prompt: String) -> String? {
        guard let line = prompt.split(whereSeparator: \.isNewline).last,
              let marker = line.range(of: "for ", options: .backwards) else {
            return nil
        }
        let value = line[marker.upperBound...]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
