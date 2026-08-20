////
//  WorkspaceState.swift
//  Colofa
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceState {
    var isPresentingRepositoryPicker = false
    var isShowingInspector = false
    var configurationEditingScope = GitConfigurationEditScope.repository
    var selectedChange: RepositoryChangeSelection?
    var commitDraft = CommitMessageDraft()
    var isConfirmingHistoryRewrite = false
    var isShowingStaleAmendAlert = false

    // Not private: the History extension in WorkspaceState+History.swift owns both of these, and
    // Swift keeps `private` within one file. Nothing else writes to them.
    var storedSidebarSelection = SidebarSelection.section(.changes)
    var historyPresentation = HistoryPresentation()

    /// Which layout the Diff pane uses, and which walk History reads. Deliberately not
    /// persisted, and deliberately outside `historyPresentation`: both are how the user wants to
    /// read this session rather than state belonging to a Repository or a Ref.
    var diffLayout = DiffLayout.unified
    var historyScope = HistoryScope.reachable

    // Not private: the Diff extension in WorkspaceState+Diff.swift owns everything below, and
    // Swift keeps `private` within one file. Nothing else writes to them.
    var diff: DiffLoadState?
    var diffFileURL: URL?
    var diffLoadID = 0
    var loadedDiffKey: DiffKey?
    var loadedDiffKind: RepositoryChangeKind?
    var confirmedDiffKey: DiffKey?

    /// Counts authoritative Repository reads. A Diff is a view of content Colofa did not read
    /// with the snapshot, so every reload has to re-ask rather than assume the patch still holds.
    private(set) var repositoryGeneration = 0

    private(set) var repository: RepositorySnapshot?
    private(set) var repositoryFailure: RepositoryFailurePresentation?
    private(set) var isLoadingRepository = false
    private(set) var isPerformingMutation = false
    private(set) var gitAvailability: GitAvailability?

    /// `UserDefaults` key holding the most recently opened Repository path. UI tests seed it
    /// by passing `-lastRepositoryPath <path>` as a launch argument.
    private static let lastRepositoryPathKey = "lastRepositoryPath"

    // Not private: the Diff extension reads patches through it directly, because a Diff is not
    // published Repository state and does not travel with a snapshot.
    let repositoryService: RepositoryService
    let pasteboard: PasteboardWriter
    private let userDefaults: UserDefaults
    private let launchArguments: [String]
    private var hasStarted = false
    private var repositoryLoadID = 0
    private var activeReplacementLoadID: Int?

    /// Set while an Amend Colofa itself is running, which is the one time HEAD is expected to
    /// move. Any reload publishing during that window reports Colofa's own rewrite, whichever
    /// task started it, so none of them may declare the Amend draft stale.
    private var isRewritingHead = false

    init(
        repositoryService: RepositoryService = .live(),
        pasteboard: PasteboardWriter = .live(),
        userDefaults: UserDefaults = .standard,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.repositoryService = repositoryService
        self.pasteboard = pasteboard
        self.userDefaults = userDefaults
        self.launchArguments = launchArguments
    }

    func start() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        let availability = await repositoryService.availability()
        gitAvailability = availability
        guard case .available = availability else {
            return
        }

        if isUITesting,
           !launchArguments.contains("-\(Self.lastRepositoryPathKey)") {
            return
        }

        guard let savedURL = savedRepositoryURL() else {
            if !isUITesting {
                isPresentingRepositoryPicker = true
            }
            return
        }

        let restored = await openRepository(
            at: savedURL,
            presentsFailure: false
        )
        if !restored {
            clearSavedRepository()
            isPresentingRepositoryPicker = true
        }
    }

    func handleRepositorySelection(_ result: Result<URL, any Error>) async {
        guard !isPerformingMutation else {
            return
        }
        switch result {
        case .success(let url):
            await openRepository(at: url, isReplacement: true)
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else {
                return
            }
            present(.locationUnavailable)
        }
    }

    func refresh() async {
        guard let repository, activeReplacementLoadID == nil else {
            return
        }
        _ = await openRepository(at: repository.rootURL, presentsFailure: true)
    }

    /// - Parameter rewritesHead: Whether this command moves HEAD on purpose, which only an Amend
    ///   does. Every reload that lands while it runs — the authoritative one, or an ordinary
    ///   refresh a scene activation started alongside it — then reports the rewrite Colofa asked
    ///   for, and must not mistake it for somebody else rewriting History.
    /// - Returns: Whether the command ran and succeeded, so a caller can keep composer state
    ///   after a failure the user still has to act on.
    @discardableResult
    func performMutation(
        _ arguments: [String],
        standardInput: String? = nil,
        rewritesHead: Bool = false,
        failureTitle: LocalizedStringResource = .gitOperationFailed
    ) async -> Bool {
        // Keep the mutation and authoritative reload alive if the initiating view task is cancelled.
        await Task {
            guard let repository, canMutateRepository else {
                return false
            }
            isPerformingMutation = true
            isRewritingHead = rewritesHead
            defer {
                isPerformingMutation = false
                isRewritingHead = false
            }

            var commandError: RepositoryOpenError?
            do {
                try await repositoryService.runMutation(
                    arguments,
                    standardInput,
                    repository.rootURL
                )
            } catch let error as RepositoryOpenError {
                commandError = error
            } catch {
                commandError = .commandFailed(
                    GitFailureDetails(command: "git", output: error.localizedDescription)
                )
            }

            await refresh()
            if let commandError {
                // The command rewrote nothing Colofa asked for, so a HEAD that moved anyway — a
                // Hook that rewrote it before refusing — still invalidates an open Amend draft.
                reconcileAmendDraft()
                presentMutationError(commandError, title: failureTitle)
                return false
            }
            return true
        }.value
    }

    var canReplaceRepository: Bool {
        !isPerformingMutation
    }
}

extension WorkspaceState {
    var isShowingRepositoryOpenError: Bool {
        get {
            if case .repositoryOpenAlert = repositoryFailure {
                true
            } else {
                false
            }
        }
        set {
            if !newValue {
                dismissRepositoryOpenError()
            }
        }
    }

    var isShowingRepositoryMutationError: Bool {
        get {
            if case .mutationAlert = repositoryFailure {
                true
            } else {
                false
            }
        }
        set {
            if !newValue {
                dismissRepositoryMutationError()
            }
        }
    }

    func chooseAnotherRepository() {
        repositoryFailure = nil
        isPresentingRepositoryPicker = true
    }

    func dismissRepositoryOpenError() {
        guard case .repositoryOpenAlert = repositoryFailure else {
            return
        }
        repositoryFailure = repositoryFailure?.expandedDetails
    }

    func dismissFailureDetails() {
        repositoryFailure = nil
    }

    func showRepositoryMutationErrorDetails() {
        guard case .mutationAlert = repositoryFailure,
              let expanded = repositoryFailure?.expandedDetails else {
            return
        }
        repositoryFailure = expanded
    }

    func dismissRepositoryMutationError() {
        guard case .mutationAlert = repositoryFailure else {
            return
        }
        repositoryFailure = nil
    }

    var repositoryFailureDetails: GitFailureDetails? {
        repositoryFailure.flatMap(\.details)
    }

    var repositoryFailureTitle: LocalizedStringResource? {
        repositoryFailure.flatMap(\.title)
    }

    var repositoryFailureMessage: LocalizedStringResource? {
        repositoryFailure.flatMap(\.message)
    }

    var canShowRepositoryFailureDetails: Bool {
        repositoryFailure?.canShowDetails == true
    }

    func retryGitDiscovery() async {
        gitAvailability = nil
        hasStarted = false
        await start()
    }

    @discardableResult
    private func openRepository(
        at url: URL,
        presentsFailure: Bool = true,
        isReplacement: Bool = false
    ) async -> Bool {
        repositoryLoadID += 1
        let loadID = repositoryLoadID
        if isReplacement {
            activeReplacementLoadID = loadID
        }
        isLoadingRepository = true
        defer {
            if loadID == repositoryLoadID {
                isLoadingRepository = false
            }
            if activeReplacementLoadID == loadID {
                activeReplacementLoadID = nil
            }
        }

        do {
            let repository = try await repositoryService.load(url)
            guard loadID == repositoryLoadID else {
                return false
            }
            publishRepository(repository)
            return true
        } catch let error as RepositoryOpenError {
            guard loadID == repositoryLoadID else {
                return false
            }
            if case .gitUnavailable = error {
                gitAvailability = .unavailable
            }
            if presentsFailure {
                present(error)
            }
            return false
        } catch {
            guard loadID == repositoryLoadID else {
                return false
            }
            if presentsFailure {
                present(
                    .commandFailed(
                        GitFailureDetails(command: "git", output: error.localizedDescription)
                    )
                )
            }
            return false
        }
    }

    private func savedRepositoryURL() -> URL? {
        guard let savedPath = userDefaults.string(forKey: Self.lastRepositoryPathKey) else {
            return nil
        }
        return URL(filePath: savedPath, directoryHint: .isDirectory)
    }

    private func clearSavedRepository() {
        userDefaults.removeObject(forKey: Self.lastRepositoryPathKey)
    }

    private func publishRepository(_ repository: RepositorySnapshot) {
        let isSameRepository = self.repository?.rootURL == repository.rootURL
        self.repository = repository
        repositoryGeneration += 1
        if !isSameRepository {
            // A message written for one Repository must not follow the user into another.
            commitDraft.clear()
            isConfirmingHistoryRewrite = false
            isShowingStaleAmendAlert = false
        } else if !isRewritingHead {
            reconcileAmendDraft()
        }
        updateSelectedChange(for: repository)
        updateHistoryReference(for: repository, isSameRepository: isSameRepository)
        repositoryFailure = nil
        guard !isUITesting else {
            return
        }
        userDefaults.set(
            repository.rootURL.normalizedFilePath,
            forKey: Self.lastRepositoryPathKey
        )
    }

    private func present(_ error: RepositoryOpenError) {
        repositoryFailure = .repositoryOpenAlert(error)
    }

    private func presentMutationError(
        _ error: RepositoryOpenError,
        title: LocalizedStringResource
    ) {
        repositoryFailure = .mutationAlert(error, title: title)
    }

    // Not private: the configuration extension in WorkspaceState+Configuration.swift needs it.
    var canMutateRepository: Bool {
        !isPerformingMutation && activeReplacementLoadID == nil
    }

    private var isUITesting: Bool {
#if DEBUG
        launchArguments.contains(UITestingArgument.enabled)
#else
        false
#endif
    }
}
