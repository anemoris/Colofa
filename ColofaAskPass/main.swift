////
//  main.swift
//  ColofaAskPass
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The AskPass program Git and OpenSSH run when they need a secret.
///
/// It exists as its own executable rather than as a mode of the app so that the program handed a
/// question — and started by Git, by `ssh`, and by anything either of them starts — carries none
/// of the app's code and none of its entitlements. It relays one question to the Colofa that
/// started it, prints the answer, and exits.
///
/// Started by anyone else, it finds no channel in its environment and declines, which is what an
/// AskPass program does when it has no answer.
guard let helper = GitAskPassHelper.pending(in: ProcessInfo.processInfo.environment) else {
    exit(1)
}

exit(helper.run(arguments: CommandLine.arguments))
