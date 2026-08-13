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
    var selectedSection = WorkspaceSection.changes
    var isPresentingRepositoryPicker = false
    var isShowingInspector = false
    var configurationEditingScope = GitConfigurationEditScope.repository
    var selectedChange: RepositoryChangeSelection?
    private(set) var repository: RepositorySnapshot?
    private(set) var repositoryFailure: RepositoryFailurePresentation?
    private(set) var isLoadingRepository = false
    private(set) var isPerformingMutation = false
    private(set) var gitAvailability: GitAvailability?

    /// `UserDefaults` key holding the most recently opened Repository path. UI tests seed it
    /// by passing `-lastRepositoryPath <path>` as a launch argument.
    private static let lastRepositoryPathKey = "lastRepositoryPath"

    private let repositoryService: RepositoryService
    private let userDefaults: UserDefaults
    private let launchArguments: [String]
    private var hasStarted = false
    private var repositoryLoadID = 0
    private var activeReplacementLoadID: Int?

    init(
        repositoryService: RepositoryService = .live(),
        userDefaults: UserDefaults = .standard,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.repositoryService = repositoryService
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

    func performMutation(
        _ arguments: [String],
        failureTitle: LocalizedStringResource = .gitOperationFailed
    ) async {
        // Keep the mutation and authoritative reload alive if the initiating view task is cancelled.
        await Task {
            guard let repository, canMutateRepository else {
                return
            }
            isPerformingMutation = true
            defer { isPerformingMutation = false }

            var commandError: RepositoryOpenError?
            do {
                try await repositoryService.runMutation(arguments, repository.rootURL)
            } catch let error as RepositoryOpenError {
                commandError = error
            } catch {
                commandError = .commandFailed(
                    GitFailureDetails(command: "git", output: error.localizedDescription)
                )
            }

            await refresh()
            if let commandError {
                presentMutationError(commandError, title: failureTitle)
            }
        }.value
    }

    func change(for selection: RepositoryChangeSelection) -> RepositoryChange? {
        guard let repository else {
            return nil
        }
        return changes(in: repository, staged: selection.isStaged)
            .first { $0.path == selection.path }
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
        guard case .repositoryOpenAlert(let error) = repositoryFailure else {
            return
        }
        if let details = error.failureDetails {
            repositoryFailure = .details(details, message: error.message)
        } else {
            repositoryFailure = nil
        }
    }

    func dismissFailureDetails() {
        repositoryFailure = nil
    }

    func showRepositoryMutationErrorDetails() {
        guard case .mutationAlert(let error, _) = repositoryFailure,
              let details = error.failureDetails else {
            return
        }
        repositoryFailure = .details(details, message: mutationMessage(for: error))
    }

    func dismissRepositoryMutationError() {
        guard case .mutationAlert = repositoryFailure else {
            return
        }
        repositoryFailure = nil
    }

    var repositoryFailureDetails: GitFailureDetails? {
        if case .details(let details, _) = repositoryFailure {
            details
        } else {
            nil
        }
    }

    var repositoryFailureTitle: LocalizedStringResource? {
        switch repositoryFailure {
        case .repositoryOpenAlert(let error):
            error.title
        case .mutationAlert(_, let title):
            title
        case .details, nil:
            nil
        }
    }

    var repositoryFailureMessage: LocalizedStringResource? {
        switch repositoryFailure {
        case .repositoryOpenAlert(let error):
            error.message
        case .mutationAlert(let error, _):
            mutationMessage(for: error)
        case .details(_, let message):
            message
        case nil:
            nil
        }
    }

    var canShowRepositoryFailureDetails: Bool {
        if case .mutationAlert(let error, _) = repositoryFailure {
            error.failureDetails != nil
        } else {
            false
        }
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
        self.repository = repository
        updateSelectedChange(for: repository)
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

    private func mutationMessage(for error: RepositoryOpenError) -> LocalizedStringResource {
        if case .commandFailed = error {
            .gitMutationFailedDescription
        } else {
            error.message
        }
    }

    // Not private: the configuration extension in WorkspaceState+Configuration.swift needs it.
    var canMutateRepository: Bool {
        !isPerformingMutation && activeReplacementLoadID == nil
    }

    private func updateSelectedChange(for repository: RepositorySnapshot) {
        guard let selectedChange else {
            return
        }
        if changes(in: repository, staged: selectedChange.isStaged)
            .contains(where: { $0.path == selectedChange.path }) {
            return
        }
        let alternate = RepositoryChangeSelection(
            path: selectedChange.path,
            isStaged: !selectedChange.isStaged
        )
        self.selectedChange = changes(in: repository, staged: alternate.isStaged)
            .contains(where: { $0.path == alternate.path }) ? alternate : nil
    }

    private func changes(
        in repository: RepositorySnapshot,
        staged: Bool
    ) -> [RepositoryChange] {
        staged ? repository.stagedChanges : repository.unstagedChanges
    }

    private var isUITesting: Bool {
#if DEBUG
        launchArguments.contains(UITestingArgument.enabled)
#else
        false
#endif
    }
}
