//
//  AfterTests.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 4/30/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

extension XCTestExpectation {
    open func fulfill(error: Error) {
        fulfill()
    }
}

class AfterTests: XCTestCase {
    func fail() { XCTFail() }
    
    func testZero() {
        let ex2 = expectation(description: "")
        let cc2 = afterCC(seconds: 0).doneCC(fail).catchCC(policy: .allErrors, ex2.fulfill)
        cc2.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
        let ex3 = expectation(description: "")
        let cc3 = afterCC(.seconds(0)).doneCC(fail).catchCC(policy: .allErrors, ex3.fulfill)
        cc3.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
//        #if !SWIFT_PACKAGE
//        let ex4 = expectation(description: "")
//        __PMKAfter(0).done { _ in ex4.fulfill() }.silenceWarning()
//        waitForExpectations(timeout: 2, handler: nil)
//        #endif
    }
    
    func testNegative() {
        let ex2 = expectation(description: "")
        let cc2 = afterCC(seconds: -1).doneCC(fail).catchCC(policy: .allErrors, ex2.fulfill)
        cc2.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
        let ex3 = expectation(description: "")
        let cc3 = afterCC(.seconds(-1)).doneCC(fail).catchCC(policy: .allErrors, ex3.fulfill)
        cc3.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
//        #if !SWIFT_PACKAGE
//        let ex4 = expectation(description: "")
//        __PMKAfter(-1).done{ _ in ex4.fulfill() }.silenceWarning()
//        waitForExpectations(timeout: 2, handler: nil)
//        #endif
    }
    
    func testPositive() {
        let ex2 = expectation(description: "")
        let cc2 = afterCC(seconds: 1).doneCC(fail).catchCC(policy: .allErrors, ex2.fulfill)
        cc2.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
        let ex3 = expectation(description: "")
        let cc3 = afterCC(.seconds(1)).doneCC(fail).catchCC(policy: .allErrors, ex3.fulfill)
        cc3.cancel()
        waitForExpectations(timeout: 2, handler: nil)
        
        #if !SWIFT_PACKAGE
        let ex4 = expectation(description: "")
        __PMKAfter(1).done{ _ in ex4.fulfill() }.silenceWarning()
        waitForExpectations(timeout: 2, handler: nil)
        #endif
    }

    func testCancellableAfter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        // Test the normal 'after' function
        let exComplete = expectation(description: "after completes")
        let afterPromise = after(seconds: 0)
        afterPromise.done {
            exComplete.fulfill()
        }.catch { error in
            XCTFail("afterPromise failed with error: \(error)")
        }
        
        let contextIgnore = CancelContext()
        let exCancelComplete = expectation(description: "after completes")
        
        // Test 'afterCC' to ensure it is fulfilled if not cancelled
        let cancelIgnoreAfterPromise = afterCC(seconds: 0, cancel: contextIgnore)
        cancelIgnoreAfterPromise.doneCC {
            exCancelComplete.fulfill()
        }.catchCC(policy: .allErrors) { error in
            XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
        let context = CancelContext()
        
        // Test 'afterCC' to ensure it is cancelled
        let cancellableAfterPromise = afterCC(seconds: 0, cancel: context)
        cancellableAfterPromise.doneCC {
            XCTFail("cancellableAfter not cancelled")
        }.catchCC(policy: .allErrorsExceptCancellation) { error in
            XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
        // Test 'afterCC' to ensure it is cancelled and throws a 'CancellableError'
        let exCancel = expectation(description: "after cancels")
        let cancellableAfterPromiseWithError = afterCC(seconds: 0, cancel: context)
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
        
        let promise = Promise<Void>(cancel: context) { seal in
            seal.fulfill()
        }
        promise.doneCC { _ in
            XCTFail("done not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testCancelForGuarantee_Done() {
        let exComplete = expectation(description: "done is cancelled")
        
        afterCC(seconds: 0).doneCC { _ in
            XCTFail("done not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
}
