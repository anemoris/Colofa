////
//  WorkspaceState+LastFetch.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
////

import Foundation

/// When Colofa last contacted a remote of a Repository.
///
/// App-owned bookkeeping rather than something Git records, which is why it lives beside the
/// commands that write it rather than inside any one of them: an ordinary Fetch, a Fetch
/// Remotes, and the Fetch half of a Pull all reach a remote, and all record it here.
extension WorkspaceState {

    /// When Colofa last fetched `url`, or `nil` when it never has.
    ///
    /// Kept per Repository so reopening an earlier one never inherits another's time.
    func storedFetchDate(of url: URL) -> Date? {
        userDefaults.dictionary(forKey: Self.lastFetchDatesKey)?[url.normalizedFilePath] as? Date
    }

    private static var lastFetchDatesKey: String { "lastFetchDates" }

    /// Records that Colofa has just contacted a remote of the open Repository.
    func recordFetch(at date: Date) {
        guard let repository else {
            return
        }
        lastFetchDate = date
        guard !isUITesting else {
            return
        }
        var dates = userDefaults.dictionary(forKey: Self.lastFetchDatesKey) ?? [:]
        dates[repository.rootURL.normalizedFilePath] = date
        userDefaults.set(dates, forKey: Self.lastFetchDatesKey)
    }
}
