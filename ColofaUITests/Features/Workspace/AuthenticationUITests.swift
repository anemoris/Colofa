////
//  AuthenticationUITests.swift
//  ColofaUITests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import XCTest

/// Authentication Requests driven the way a user meets them: a Fetch that needs a secret, the
/// prompt it opens, and what pressing each of its buttons does to the command underneath.
final class AuthenticationUITests: XCTestCase {
    private static let secret = "ghp_ColofaFixtureToken"
    private static let fetchedRemoteBranch = "repository.ref.remote.origin/新分支"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// An HTTPS password is asked for natively, entered without being shown, and the Fetch it was
    /// blocking finishes once it is given.
    @MainActor
    func testEnglishAnHTTPSPasswordRequestIsAnsweredWithoutBeingShown() {
        let application = fetchingApplication(.password)

        let field = application.descendants(matching: .any)["repository.authentication.answer"]
        assertEventuallyExists(field, "The Fetch never asked for a password")
        XCTAssertTrue(
            application.sheets.staticTexts["Password Required"].exists,
            "The prompt did not say what it was asking for"
        )
        XCTAssertEqual(application.sheets.secureTextFields.count, 1)
        XCTAssertEqual(application.sheets.textFields.count, 0, "A password was entered in the open")
        // The prompt opens focused on the field it exists to fill, so what is typed reaches it
        // without the user clicking anything first.
        paste(Self.secret, into: application)
        let reported = field.value as? String ?? ""
        XCTAssertEqual(
            reported.count,
            Self.secret.count,
            "The prompt did not open focused on the field it exists to fill"
        )
        XCTAssertNotEqual(reported, Self.secret, "A secure field showed what was typed")

        application.descendants(matching: .any)["repository.authentication.confirm"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)[Self.fetchedRemoteBranch],
            "Answering the prompt did not let the Fetch finish"
        )
    }

    /// The remote the question is about is named, so the user knows what they are authenticating
    /// to before they type anything.
    @MainActor
    func testEnglishAPasswordRequestNamesTheRemoteItIsAbout() {
        let application = fetchingApplication(.password)

        let subject = application.descendants(matching: .any)["repository.authentication.subject"]
        assertEventuallyExists(subject, "The prompt did not name what it was asking about")
        XCTAssertTrue(
            application.sheets.staticTexts["https://example.invalid/Colofa.git"].exists,
            "The prompt did not show the remote it was authenticating to"
        )
    }

    /// An account name is not a secret and is not hidden while it is typed, and the prompt
    /// refuses to submit an empty one.
    @MainActor
    func testEnglishAnAccountNameIsEnteredInTheOpenAndCannotBeEmpty() {
        let application = fetchingApplication(.username)

        let field = application.descendants(matching: .any)["repository.authentication.answer"]
        assertEventuallyExists(field, "The Fetch never asked for an account name")
        XCTAssertEqual(application.sheets.secureTextFields.count, 0)

        let confirm = application.descendants(matching: .any)["repository.authentication.confirm"]
        XCTAssertFalse(confirm.isEnabled, "An empty account name could be submitted")

        replaceText(of: field, with: "octocat")
        XCTAssertTrue(confirm.isEnabled)
        confirm.click()

        assertEventuallyExists(
            application.descendants(matching: .any)[Self.fetchedRemoteBranch],
            "Answering the prompt did not let the Fetch finish"
        )
    }

    /// An SSH passphrase is asked for the same way, and names the key rather than a remote.
    @MainActor
    func testEnglishAnSSHPassphraseRequestNamesTheKeyAndHidesWhatIsTyped() {
        let application = fetchingApplication(.passphrase)

        let field = application.descendants(matching: .any)["repository.authentication.answer"]
        assertEventuallyExists(field, "The Fetch never asked for a passphrase")
        XCTAssertTrue(application.sheets.staticTexts["Passphrase Required"].exists)
        XCTAssertTrue(
            application.sheets.staticTexts["/Users/colofa/.ssh/id_ed25519"].exists,
            "The prompt did not name the key it was unlocking"
        )
        XCTAssertEqual(application.sheets.secureTextFields.count, 1)

        replaceSecureText(of: field, with: "correct horse")
        application.descendants(matching: .any)["repository.authentication.confirm"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)[Self.fetchedRemoteBranch],
            "Answering the prompt did not let the Fetch finish"
        )
    }

    /// A host OpenSSH has never seen is a recognition, not an entry: the fingerprint is shown in
    /// full and there is nothing to type.
    @MainActor
    func testEnglishANewSSHHostShowsItsFingerprintAndIsTrustedExplicitly() {
        let application = fetchingApplication(.hostKey)

        let fingerprint = application.descendants(
            matching: .any
        )["repository.authentication.fingerprint"]
        assertEventuallyExists(fingerprint, "The new host was not put in front of the user")
        XCTAssertTrue(application.sheets.staticTexts["New SSH Host"].exists)
        XCTAssertTrue(
            application.sheets.staticTexts[
                "SHA256:0oIfXeSKQ5wPq7nT2m8fCk4vJb1yWx9AZs6EdLuGhRq"
            ].exists,
            "The fingerprint was not shown in full"
        )
        XCTAssertTrue(application.sheets.staticTexts["example.invalid"].exists)
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.authentication.answer"].exists,
            "A host key was turned into something to type"
        )

        application.sheets.buttons["Trust and Continue"].click()

        assertEventuallyExists(
            application.descendants(matching: .any)[Self.fetchedRemoteBranch],
            "Trusting the host did not let the Fetch finish"
        )
    }

    /// The one question the app never asks. A changed host key is refused, and nothing anywhere
    /// offers a way past it.
    @MainActor
    func testEnglishAChangedSSHHostKeyIsRefusedWithNoWayToContinue() {
        let application = fetchingApplication(.hostKeyChanged)

        assertEventuallyExists(
            application.sheets.staticTexts["SSH Host Key Changed"],
            "A changed host key was not reported"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.authentication.answer"].exists,
            "A changed host key was put to the user as a question"
        )
        XCTAssertFalse(application.sheets.buttons["Trust and Continue"].exists)
        XCTAssertFalse(application.sheets.buttons["Continue"].exists)
        XCTAssertTrue(application.sheets.buttons["View Details"].exists)
        application.sheets.buttons["OK"].click()

        XCTAssertFalse(
            application.descendants(matching: .any)[Self.fetchedRemoteBranch].exists,
            "A refused connection still fetched something"
        )
    }

    /// Cancelling the prompt cancels the command that asked, and a Cancel is not reported back as
    /// a failure.
    @MainActor
    func testEnglishCancellingTheRequestCancelsTheFetchWithoutReportingAFailure() {
        let application = fetchingApplication(.password)

        let cancel = application.descendants(matching: .any)["repository.authentication.cancel"]
        assertEventuallyExists(cancel, "The Fetch never asked for anything")
        cancel.click()

        assertEventuallyExists(
            application.descendants(matching: .any)["repository.toolbar.fetch"],
            "Cancelling the prompt did not end the Fetch"
        )
        XCTAssertFalse(
            application.descendants(matching: .any)["repository.authentication.answer"].exists
        )
        XCTAssertFalse(
            application.sheets.buttons["View Details"].exists,
            "A Cancel was reported as a failure"
        )
        XCTAssertEqual(
            application.descendants(matching: .any)["repository.lastFetch"].value as? String,
            "Never",
            "A cancelled Fetch recorded a time"
        )
    }

    /// A question Colofa cannot classify is still asked, is shown exactly as it arrived, and is
    /// answered secretly.
    @MainActor
    func testEnglishAnUnrecognizedQuestionIsShownAsItWasAsked() {
        let application = fetchingApplication(.unrecognized)

        let prompt = application.descendants(matching: .any)["repository.authentication.prompt"]
        assertEventuallyExists(prompt, "An unrecognized question was never asked")
        XCTAssertEqual(
            prompt.value as? String,
            "Colofa fixture asks something nobody classified:"
        )
        XCTAssertEqual(application.sheets.secureTextFields.count, 1)
    }

    /// A question long enough to fill the sheet does not push the buttons that answer it out of
    /// reach. How long a question is was decided by whoever asked it, so the question scrolls and
    /// Cancel and Continue stay where the user can press them.
    @MainActor
    func testEnglishALongQuestionKeepsTheAnswerButtonsReachable() {
        let application = fetchingApplication(.longPrompt)

        let prompt = application.descendants(matching: .any)["repository.authentication.prompt"]
        assertEventuallyExists(prompt, "A long question was never asked")

        let confirm = application.descendants(matching: .any)["repository.authentication.confirm"]
        let cancel = application.descendants(matching: .any)["repository.authentication.cancel"]
        XCTAssertTrue(confirm.isHittable, "The button that answers the question is out of reach")
        XCTAssertTrue(cancel.isHittable, "The button that refuses the question is out of reach")
        XCTAssertTrue(
            application.windows.firstMatch.frame.contains(confirm.frame),
            "A long question grew the sheet past the window it is attached to"
        )
    }

    /// Which question the fixture's Git asks.
    private enum Question {
        case username
        case password
        case passphrase
        case hostKey
        case hostKeyChanged
        case unrecognized
        case longPrompt

        var argument: String {
            switch self {
            case .username: UITestingArgument.authenticationUsername
            case .password: UITestingArgument.authenticationPassword
            case .passphrase: UITestingArgument.authenticationPassphrase
            case .hostKey: UITestingArgument.authenticationHostKey
            case .hostKeyChanged: UITestingArgument.authenticationHostKeyChanged
            case .unrecognized: UITestingArgument.authenticationUnrecognized
            case .longPrompt: UITestingArgument.authenticationLongPrompt
            }
        }
    }

    @MainActor
    private func authenticatingApplication(_ question: Question) -> XCUIApplication {
        XCUIApplication.configuredForFetchState(
            path: FileManager.default.temporaryDirectory.path(percentEncoded: false),
            additionalArguments: [UITestingArgument.singleRemote, question.argument]
        )
    }

    /// Launches the fixture and presses Fetch once the window is ready to run one.
    ///
    /// The Repository is restored after launch, so Fetch is disabled for as long as that takes.
    /// Pressing it before then presses nothing, and the prompt that never opens reads as a Fetch
    /// that never asked.
    @MainActor
    private func fetchingApplication(_ question: Question) -> XCUIApplication {
        let application = authenticatingApplication(question)
        application.launch()
        application.activate()

        let fetch = application.descendants(matching: .any)["repository.toolbar.fetch"]
        XCTAssertTrue(
            waitUntil(NSPredicate(format: "isEnabled == true"), on: fetch),
            "The window never became ready to Fetch"
        )
        fetch.click()
        return application
    }
}
