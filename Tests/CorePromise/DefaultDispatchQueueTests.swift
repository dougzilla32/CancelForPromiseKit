//
//  PMKDefaultDispatchQueue.test.swift
//  PromiseKit
//
//  Created by David Rodriguez on 4/14/16.
//  Copyright © 2016 Max Howell. All rights reserved.
//

import class Foundation.Thread
import PromiseKit
@testable import CancelForPromiseKit
import Dispatch
import XCTest

private enum Error: Swift.Error { case dummy }

class CPKDefaultDispatchQueueTest: XCTestCase {

    let myQueue = DispatchQueue(label: "myQueue")

    override func setUp() {
        // can actually only set the default queue once
        // - See: PMKSetDefaultDispatchQueue
        conf.Q = (myQueue, myQueue)
    }

    override func tearDown() {
        conf.Q = (.main, .main)
    }

    func testOverrodeDefaultThenQueue() {
        let ex = expectation(description: "resolving")

        let p = Promise.valueCC(1)
        print("p.cancel()")
        p.cancel()
        p.thenCC { _ -> Promise<Void> in
            print("thenCC")
            XCTFail()
            XCTAssertFalse(Thread.isMainThread)
            return Promise()
        }.catchCC(policy: .allErrors) {
            print("catchCC")
            $0.isCancelled ? ex.fulfill() : XCTFail()
            XCTAssertFalse(Thread.isMainThread)
        }

        XCTAssertTrue(Thread.isMainThread)

        waitForExpectations(timeout: 1)
    }

    func testOverrodeDefaultCatchQueue() {
        let ex = expectation(description: "resolving")

        let p = Promise<Int>(cancel: CancelContext(), error: Error.dummy)
        p.cancel()
        p.catchCC { _ in
            ex.fulfill()
            XCTAssertFalse(Thread.isMainThread)
        }

        XCTAssertTrue(Thread.isMainThread)

        waitForExpectations(timeout: 1)
    }

    func testOverrodeDefaultAlwaysQueue() {
        let ex = expectation(description: "resolving")
        let ex2 = expectation(description: "catching")

        let p = Promise.valueCC(1)
        p.cancel()
        p.ensureCC {
            ex.fulfill()
            XCTAssertFalse(Thread.isMainThread)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex2.fulfill() : XCTFail()
            XCTAssertFalse(Thread.isMainThread)
        }

        XCTAssertTrue(Thread.isMainThread)

        waitForExpectations(timeout: 1)
    }
}
