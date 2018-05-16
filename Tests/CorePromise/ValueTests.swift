//
//  ValueTests.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 4/30/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

class ValueTests: XCTestCase {
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
}
