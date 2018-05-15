//
//  CancelTests.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 4/30/18.
//

import XCTest
import CancelForPromiseKit
import PromiseKit

class CancelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

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
    
    func testValueContext() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        Promise.valueCC("hi", cancel: context).doneCC { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueCCDoneCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        Promise.valueCC("hi", cancel: context).doneCC { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueCCThenCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        Promise.valueCC("hi", cancel: context).thenCC { (_: String) -> Promise<String> in
            XCTFail("value not cancelled")
            return Promise.valueCC("bye")
        }.doneCC { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueDoneCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        Promise.value("hi").doneCC(cancel: context) { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDoneCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        firstly {
            Promise.value("hi")
        }.doneCC(cancel: context) { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyCCValueDoneCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        firstlyCC(cancel: context) {
            Promise.value("hi")
        }.doneCC { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()

        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDifferentContextDone() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        firstlyCC {
            Promise.valueCC("hi", cancel: context)
        }.doneCC { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDoneDifferentContext() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        
        firstlyCC {
            Promise.value("hi")
        }.doneCC(cancel: context) { _ in
            XCTFail("value not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
   func testCancelForPromise_Then() {
        let exComplete = expectation(description: "after completes")
        let context = CancelContext()
        
        let promise = Promise<Void>(cancel: context) { seal in
            usleep(100000)
            seal.fulfill()
        }
        promise.thenCC { () throws -> Promise<String>  in
            XCTFail("then not cancelled")
            return Promise.value("x")
        }.doneCC { _ in
            XCTFail("done not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }

    func testCancelForPromise_ThenDone() {
        let exComplete = expectation(description: "done is cancelled")
        let noopContext = CancelContext()
        let context = CancelContext()

        let promise = Promise<Void>(cancel: context) { seal in
            usleep(100000)
            seal.fulfill()
        }
        promise.thenCC(cancel: noopContext) { _ in
            return Promise.valueCC("x")
        }.doneCC(cancel: context) { _ in
            XCTFail("done not cancelled")
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()

        wait(for: [exComplete], timeout: 1)
    }
    
    func testCancelForPromise_Done() {
        let exComplete = expectation(description: "after completes")
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
