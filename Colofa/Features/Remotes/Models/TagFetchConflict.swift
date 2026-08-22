////
//  TagFetchConflict.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation

/// The local tags a remote's tags of the same name point somewhere else.
///
/// Git refuses to replace such a tag on its own, and Colofa never overrides that: an explicit
/// Fetch Tags may add tags, never force-update or prune one. What this adds is the list of names,
/// so the refusal says which tags Git kept rather than only that the command exited non-zero.
///
/// Read only after Git has already refused, so it explains a refusal rather than deciding one.
nonisolated struct TagFetchConflict: Equatable, Sendable {

    /// The tag names that exist locally and on the remote, pointing at different objects.
    let tags: [String]

    /// How many names a refusal lists before summarizing the rest, so an alert stays readable
    /// when a remote disagrees about hundreds of tags.
    static let listedTagLimit = 10

    static let empty = Self(tags: [])

    var isEmpty: Bool {
        tags.isEmpty
    }

    /// Which tags Git kept, and why the command stopped short of the rest.
    var message: LocalizedStringResource {
        .fetchTagsRefusedDescription(tagList)
    }

    /// The listed names, one per line, ending with a count of whatever did not fit.
    var tagList: String {
        let listed = tags.prefix(Self.listedTagLimit).joined(separator: "\n")
        guard tags.count > Self.listedTagLimit else {
            return listed
        }
        let remaining = String(
            localized: .fetchTagsRefusedMoreTags(
                (tags.count - Self.listedTagLimit).formatted(.number)
            )
        )
        return "\(listed)\n\(remaining)"
    }

    /// Whether Git's own failure output names one of these tags.
    ///
    /// Git's rejection line is translated — both `[rejected]` and `would clobber existing tag`
    /// come out of Git's message catalog in the user's language — so matching on its wording
    /// would only work in English. The ref names in it are not translated, which makes them the
    /// one part of the line Colofa can read anywhere.
    ///
    /// This is what separates a refusal about tags from a Hook, a refspec, or an unreachable
    /// remote that failed the same command while the two sides happened to disagree about a tag
    /// name anyway.
    func isNamed(in failureOutput: String) -> Bool {
        let named = Set(failureOutput.split(whereSeparator: \.isWhitespace).map(String.init))
        return tags.contains { named.contains($0) }
    }

    /// Where the remote and the Repository disagree about what a tag name points at.
    ///
    /// A name only the remote holds is a tag the Fetch adds, and a name both hold at the same
    /// object is one it leaves alone; neither is a conflict.
    static func evaluate(
        remoteTags: [String: String],
        localTags: [String: String]
    ) -> Self {
        Self(
            tags: remoteTags
                .filter { name, objectID in
                    guard let localObjectID = localTags[name] else {
                        return false
                    }
                    return localObjectID != objectID
                }
                .keys
                .sorted()
        )
    }
}

nonisolated struct TagConflictRequest: Equatable, Sendable {
    let repositoryURL: URL

    /// The remote the tags would have come from.
    let remote: String
}
