//
//  CancellablePromiseKitTests.swift
//  CancellablePromiseKitTests
//
//  Created by Doug Stein on 4/30/18.
//

import XCTest
import CancelForPromiseKit
import PromiseKit

class CancellablePromiseKitTests: XCTestCase {
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

        // Test 'cancellableAfter' to ensure it is fulfilled if not cancelled
        let cancelIgnoreAfterPromise = after(seconds: 0.1, cancel: contextIgnore)
        cancelIgnoreAfterPromise.done {
            exCancelComplete.fulfill()
        }.catch(policy: .allErrors) { error in
            XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
       let context = CancelContext()
        
        // Test 'cancellableAfter' to ensure it is cancelled
        let cancellableAfterPromise = after(seconds: 0.1, cancel: context)
        cancellableAfterPromise.done {
            XCTFail("cancellableAfter not cancelled")
        }.catch(policy: .allErrorsExceptCancellation) { error in
            XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        
        // Test 'cancellableAfter' to ensure it is cancelled and throws a 'CancellableError'
        let exCancel = expectation(description: "after cancels")
        let cancellableAfterPromiseWithError = after(seconds: 0.1, cancel: context)
        cancellableAfterPromiseWithError.done {
            XCTFail("cancellableAfterWithError not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exCancel.fulfill() : XCTFail("unexpected error \(error)")
        }

        context.cancel()
        wait(for: [exComplete, exCancelComplete, exCancel], timeout: 1)
    }
    
    func testValueContext() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        Promise.value("hi", cancel: context).done() { value in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueDone() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        Promise.value("hi").done(cancel: context) { value in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueDoneCC() {
        let context = CancelContext()
        let exComplete = expectation(description: "after completes")
        Promise.value("hi", cancel: context).doneCC() { value in
            print("done")
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        print("cancel")
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    /*
    func testCancelForPromise_Then() {
        let failAndValue: (()) -> Promise<String> = {
            XCTFail("then not cancelled")
            return Promise.value("x")
        }
        let exComplete = expectation(description: "after completes")
        let context = CancelContext()
        
        let promise = Promise<Void> { seal in
            sleep(100)
            seal.fulfill()
        }
        promise.then(cancel: context) { value in
            return failAndValue()
        }.done(cancel: context) { value in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }

    func testCancelForPromise_ThenDone() {
        let exComplete = expectation(description: "done is cancelled")
        let noopContext = CancelContext()
        let context = CancelContext()

        let promise = Promise<Void> { seal in
            sleep(100)
            seal.fulfill()
        }
        promise.then(cancel: noopContext) { value in
            return Promise.value("x")
        }.done(cancel: context) { value in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()

        wait(for: [exComplete], timeout: 1)
    }
    */
        
    func testCancelForPromise_Done() {
        let exComplete = expectation(description: "after completes")
        let context = CancelContext()
        
        let promise = Promise<Void> { seal in
            sleep(100)
            seal.fulfill()
        }
        promise.done(cancel: context) { value in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testCancelForGuarantee_Done() {
        let exComplete = expectation(description: "done is cancelled")
        let context = CancelContext()
        
        after(seconds: 0.1).done(cancel: context) { value in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        context.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
}

public enum CancelTestError: Error {
    case yow
}

