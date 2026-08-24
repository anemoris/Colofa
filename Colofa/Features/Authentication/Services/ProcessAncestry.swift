////
//  ProcessAncestry.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Darwin

/// Whether one running process was started by another, asked of the kernel rather than of anything
/// a process says about itself.
///
/// The AskPass channel asks it because a token says which operation a program belongs to and not
/// that the program is one that operation started. Git and OpenSSH ask through programs they run
/// themselves, so descent is what separates the AskPass program a command invoked from anything
/// else that came to hold the same environment.
///
/// Only asked about a process that is still connected. A process identifier cannot be forged, but
/// it is reused once the process it named has gone, and an answer about a number nobody holds any
/// more is an answer about nothing.
///
/// Declared `nonisolated` because the project defaults to Main Actor isolation: this is asked
/// while serving a connection, off the main actor.
nonisolated enum ProcessAncestry {

    /// Whether `processID` is `ancestor`, or was started directly or indirectly by it.
    static func descends(_ processID: pid_t, from ancestor: pid_t) -> Bool {
        var current = processID
        // Bounded because each step reads the process table separately, so the tree can change
        // between two of them. A bound is what keeps that from becoming a walk with no end.
        for _ in 0..<maximumDepth {
            if current == ancestor {
                return true
            }
            // `launchd` is where every walk ends, and a process the kernel will not describe has
            // no ancestry left to read either way.
            guard current > 1, let parent = parent(of: current), parent != current else {
                return false
            }
            current = parent
        }
        return false
    }

    /// The process that started `processID`, or `nil` when the kernel will not say — which
    /// includes a process that has already ended.
    private static func parent(of processID: pid_t) -> pid_t? {
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, processID]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        // A process that no longer exists is reported as a success that filled nothing in, so the
        // size written is what says whether there is an answer here at all.
        guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        return info.kp_eproc.e_ppid
    }

    /// How far a walk may climb. Deeper than any process tree an AskPass program is invoked from,
    /// and shallow enough that a tree which somehow cycles is refused rather than followed.
    private static let maximumDepth = 64
}
