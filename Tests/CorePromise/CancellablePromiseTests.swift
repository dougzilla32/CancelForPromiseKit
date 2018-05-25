//
//  CancellablePromiseTests.swift
//  CPKCoreTests
//
//  Created by Doug on 5/21/18.
//

import PromiseKit
import CancelForPromiseKit
import XCTest

class CancellablePromiseTests: XCTestCase {
    func testCancel() {
        let ex = expectation(description: "")
        let p = CancellablePromise<Int>.pending()
        p.promise.then { (val: Int) -> CancellablePromise<String> in
            print(val)
            return CancellablePromise.value("hi")
        }.done { _ in
            XCTFail()
            ex.fulfill()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }
        p.resolver.fulfill(3)
        p.promise.cancel()

        wait(for: [ex], timeout: 1)
    }
    
    func testFirstly() {
        let ex = expectation(description: "")
        firstly {
            return CancellablePromise.value(3)
        }.then { (_: Int) -> CancellablePromise<String> in
            XCTFail()
            return CancellablePromise.value("hi")
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        
        wait(for: [ex], timeout: 1)
    }
    
    func testFirstlyWithPromise() {
        let ex = expectation(description: "")
        firstlyCC {
            return Promise.value(3)
        }.then { (_: Int) -> CancellablePromise<String> in
            XCTFail()
            return CancellablePromise.value("hi")
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail("\($0)")
        }.cancel()
        
        wait(for: [ex], timeout: 1)
    }
    
    func testThenMapSuccess() {
        let ex = expectation(description: "")
        firstly {
            CancellablePromise.value([1,2,3])
        }.thenMap { (integer: Int) -> CancellablePromise<Int> in
            return CancellablePromise.value(integer * 2)
        }.done { _ in
            ex.fulfill()
            // $0 => [2,4,6]
        }.catch(policy: .allErrors) { _ in
            XCTFail()
        }
        waitForExpectations(timeout: 1)
    }
    
    func testThenMapCancel() {
        let ex = expectation(description: "")
        firstly {
            CancellablePromise.value([1,2,3])
        }.thenMap { (integer: Int) -> CancellablePromise<Int> in
            XCTFail()
            return CancellablePromise.value(integer * 2)
        }.done { _ in
            XCTFail()
            // $0 => [2,4,6]
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        waitForExpectations(timeout: 1)
    }
    
    func testChain() {
        let ex = expectation(description: "")
        firstly {
            CancellablePromise.value(1)
        }.then { (integer: Int) -> CancellablePromise<Int> in
            XCTFail()
            return CancellablePromise.value(integer * 2)
        }.done { _ in
            // $0 => [2,4,6]
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        waitForExpectations(timeout: 1)
    }
}
