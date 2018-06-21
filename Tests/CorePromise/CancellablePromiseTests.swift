//
//  CancellablePromiseTests.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 5/21/18.
//

import Foundation
import PromiseKit
import CancelForPromiseKit
import XCTest

class CancellablePromiseTests: XCTestCase {
    func testCancel() {
        let ex = expectation(description: "")
        let p = CancellablePromise<Int>.pending()
        p.promise.then { (val: Int) -> CancellablePromise<String> in
            print(val)
            return CancellablePromise.valueCC("hi")
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
            return CancellablePromise.valueCC(3)
        }.then { (_: Int) -> CancellablePromise<String> in
            XCTFail()
            return .valueCC("hi")
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
            return .valueCC("hi")
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
            CancellablePromise.valueCC([1,2,3])
        }.thenMap { (integer: Int) -> CancellablePromise<Int> in
            return .valueCC(integer * 2)
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
            CancellablePromise.valueCC([1,2,3])
        }.thenMap { (integer: Int) -> CancellablePromise<Int> in
            XCTFail()
            return .valueCC(integer * 2)
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
            CancellablePromise.valueCC(1)
        }.then { (integer: Int) -> CancellablePromise<Int> in
            XCTFail()
            return .valueCC(integer * 2)
        }.done { _ in
            // $0 => [2,4,6]
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        waitForExpectations(timeout: 1)
    }
    
    func testBridge() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        
        let (promise, seal) = Promise<Void>.pending()
        DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now() + 0.2) { seal.fulfill(()) }

        CancellablePromise(promise).done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex2.fulfill() : XCTFail()
        }.cancel()
        
        promise.done { _ in
            ex1.fulfill()
        }.catch(policy: .allErrors) { _ in
            XCTFail()
        }
        
        waitForExpectations(timeout: 1)
    }
}
