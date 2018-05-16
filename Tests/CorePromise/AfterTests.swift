//
//  AfterTests.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 5/16/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

class AfterTests: XCTestCase {
    func testAfter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        // Test the normal 'after' function
        let exComplete = expectation(description: "after completes")
        let afterPromise = after(seconds: 0.01)
        afterPromise.done {
            exComplete.fulfill()
            }.catch { error in
                XCTFail("afterPromise failed with error: \(error)")
        }
        
        let contextIgnore = CancelContext()
        let exCancelComplete = expectation(description: "after completes")
        
        // Test 'afterCC' to ensure it is fulfilled if not cancelled
        let cancelIgnoreAfterPromise = afterCC(seconds: 0.1, cancel: contextIgnore)
        cancelIgnoreAfterPromise.doneCC {
            exCancelComplete.fulfill()
            }.catchCC(policy: .allErrors) { error in
                XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
        let context = CancelContext()
        
        // Test 'afterCC' to ensure it is cancelled
        let cancellableAfterPromise = afterCC(seconds: 0.1, cancel: context)
        cancellableAfterPromise.doneCC {
            XCTFail("cancellableAfter not cancelled")
            }.catchCC(policy: .allErrorsExceptCancellation) { error in
                XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
        // Test 'afterCC' to ensure it is cancelled and throws a 'CancellableError'
        let exCancel = expectation(description: "after cancels")
        let cancellableAfterPromiseWithError = afterCC(seconds: 0.1, cancel: context)
        cancellableAfterPromiseWithError.doneCC {
            XCTFail("cancellableAfterWithError not cancelled")
            }.catchCC(policy: .allErrors) { error in
                error.isCancelled ? exCancel.fulfill() : XCTFail("unexpected error \(error)")
        }
        
        context.cancel()
        wait(for: [exComplete, exCancelComplete, exCancel], timeout: 1)
    }
    
    func testCancelForPromise_Done() {
        let exComplete = expectation(description: "done is cancelled")
        let context = CancelContext()
        
        let promise = Promise<Void> { seal in
            usleep(100000)
            seal.fulfill()
        }
        promise.doneCC(cancel: context) { _ in
            XCTFail("done not cancelled")
            }.catchCC(policy: .allErrors) { error in
                error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testCancelForGuarantee_Done() {
        let exComplete = expectation(description: "done is cancelled")
        let context = CancelContext()
        
        after(seconds: 0.1).doneCC(cancel: context) { _ in
            XCTFail("done not cancelled")
            }.catchCC(policy: .allErrors) { error in
                error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
}
