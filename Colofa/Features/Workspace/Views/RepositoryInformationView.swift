////
//  RepositoryInformationView.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import SwiftUI

struct RepositoryInformationView: View {
    let repository: RepositorySnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                LabeledContent(String(localized: .repositoryName)) {
                    Text(verbatim: repository.name)
                }
                LabeledContent(String(localized: .repositoryPath)) {
                    Text(verbatim: repository.rootURL.normalizedFilePath)
                        .textSelection(.enabled)
                }
                LabeledContent(String(localized: .gitDirectory)) {
                    Text(verbatim: repository.gitDirectoryURL.normalizedFilePath)
                        .textSelection(.enabled)
                }
                LabeledContent(String(localized: .head)) {
                    RepositoryHeadLabel(head: repository.head)
                }
                if let upstream = repository.upstream {
                    LabeledContent(String(localized: .upstream)) {
                        Text(verbatim: upstream.name)
                    }
                }
                LabeledContent(String(localized: .repositorySize)) {
                    Text(repository.gitObjectSize, format: .byteCount(style: .file))
                }
                LabeledContent(String(localized: .commits)) {
                    Text(repository.totalCommitCount, format: .number)
                        .accessibilityIdentifier("repository.commitCount")
                }
                LabeledContent(String(localized: .branches)) {
                    Text(repository.localBranches.count, format: .number)
                }
                LabeledContent(String(localized: .tags)) {
                    Text(repository.tags.count, format: .number)
                }
                LabeledContent(String(localized: .changes)) {
                    Text(repository.changeCount, format: .number)
                }
                LabeledContent(String(localized: .remotes)) {
                    Text(repository.remotes.count, format: .number)
                }
                ForEach(repository.remotes) { remote in
                    LabeledContent {
                        Text(verbatim: remote.url)
                            .textSelection(.enabled)
                    } label: {
                        Text(verbatim: remote.name)
                    }
                }
                // Identity is the Repository, not the snapshot: the configuration fields keep
                // an unsaved draft in `@State`, which must survive a refresh of the same
                // Repository but must be discarded when a different one is opened.
                RepositoryConfigurationView(configuration: repository.configuration)
                    .id(repository.id)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
