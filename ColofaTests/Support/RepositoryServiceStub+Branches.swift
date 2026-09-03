////
//  RepositoryServiceStub+Branches.swift
//  ColofaTests
//
//  Copyright © 2026 Anemoris Studio.
//  All rights reserved.
//

import Foundation
@testable import Colofa

/// What the fixture answers about branch work.
///
/// Grouped apart because none of these is published Repository state: each stands in for a
/// read Colofa takes when one branch command is about to run, and each can be asked more than
/// once for the same Branch so a test can drive a Ref that changed in between.
extension RepositoryServiceStub {
    func validateBranchName(_ request: BranchNameValidationRequest) throws -> Bool {
        branchNameRequests.append(request)
        if let branchNameValidationError {
            throw branchNameValidationError
        }
        return !invalidBranchNames.contains(request.name)
    }

    func comparison(_ request: CheckoutComparisonRequest) throws -> CheckoutComparison {
        checkoutComparisonRequests.append(request)
        if let checkoutComparisonError {
            throw checkoutComparisonError
        }
        return checkoutComparison
    }

    /// The next answer this fixture has for `request`, keeping the last one once the queue is
    /// down to it, the same way the Repository fixture keeps its final snapshot.
    func deletionSurvey(_ request: BranchDeletionRequest) throws -> BranchDeletionSurvey? {
        branchDeletionRequests.append(request)
        if let branchDeletionSurveyError {
            throw branchDeletionSurveyError
        }
        guard var answers = branchDeletionSurveys[request.name], let survey = answers.first else {
            return nil
        }
        if answers.count > 1 {
            answers.removeFirst()
            branchDeletionSurveys[request.name] = answers
        }
        return survey
    }

    func recordedBranchNameRequests() -> [BranchNameValidationRequest] {
        branchNameRequests
    }

    func recordedCheckoutComparisonRequests() -> [CheckoutComparisonRequest] {
        checkoutComparisonRequests
    }

    func recordedBranchDeletionRequests() -> [BranchDeletionRequest] {
        branchDeletionRequests
    }
}
