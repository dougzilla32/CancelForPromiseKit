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
        let exComplete = expectation(description: "after completes")
        CancellablePromise.value("hi").done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueDone() {
        let exComplete = expectation(description: "after completes")
        CancellablePromise.value("hi").done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testValueThen() {
        let exComplete = expectation(description: "after completes")
        
        CancellablePromise.value("hi").then { (_: String) -> CancellablePromise<String> in
            XCTFail("value not cancelled")
            return CancellablePromise.value("bye")
        }.done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDone() {
        let exComplete = expectation(description: "after completes")
        
        firstly {
            CancellablePromise.value("hi")
        }.done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyThenValueDone() {
        let exComplete = expectation(description: "after completes")
        
        firstlyCC {
            Promise.value("hi")
        }.then { (_: String) -> CancellablePromise<String> in
            XCTFail("'hi' not cancelled")
            return CancellablePromise.value("there")
        }.done { _ in
            XCTFail("'there' not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()

        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDifferentContextDone() {
        let exComplete = expectation(description: "after completes")
        
        let p = firstly {
            return CancellablePromise.value("hi")
        }.done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }
        p.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testFirstlyValueDoneDifferentContext() {
        let exComplete = expectation(description: "after completes")
        
        firstlyCC {
            Promise.value("hi")
        }.done { _ in
            XCTFail("value not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }
    
    func testCancelForPromise_Then() {
        let exComplete = expectation(description: "after completes")
        
        let promise = CancellablePromise<Void> { seal in
            usleep(100000)
            seal.fulfill()
        }
        promise.then { () throws -> Promise<String> in
            XCTFail("then not cancelled")
            return Promise.value("x")
        }.done { _ in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()
        
        wait(for: [exComplete], timeout: 1)
    }

    func testCancelForPromise_ThenDone() {
        let exComplete = expectation(description: "done is cancelled")

        let promise = CancellablePromise<Void> { seal in
            usleep(100000)
            seal.fulfill()
        }
        promise.then { _ -> CancellablePromise<String> in
            XCTFail("then not cancelled")
            return CancellablePromise.value("x")
        }.done { _ in
            XCTFail("done not cancelled")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? exComplete.fulfill() : XCTFail("error: \(error)")
        }.cancel()

        wait(for: [exComplete], timeout: 1)
    }
}
