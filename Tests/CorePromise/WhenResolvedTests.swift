//  Created by Austin Feight on 3/19/16.
//  Copyright © 2016 Max Howell. All rights reserved.

import PromiseKit
import CancelForPromiseKit
import XCTest

class JoinTests: XCTestCase {
    func testImmediates() {
        let successPromise = CancellablePromise()

        var joinFinished = false
        when(resolved: successPromise).done(on: nil) { _ in joinFinished = true }.cancel()
        XCTAssert(joinFinished, "Join immediately finishes on fulfilled promise")
        
        let promise2 = Promise.value(2)
        let promise3: CancellablePromise = .valueCC(3)
        let promise4 = Promise.value(4)
        var join2Finished = false
        when(resolved: CancellablePromise(promise2), promise3, CancellablePromise(promise4)).done(on: nil) { _ in join2Finished = true }.cancel()
        XCTAssert(join2Finished, "Join immediately finishes on fulfilled promises")
    }

   func testFulfilledAfterAllResolve() {
        let (promise1, seal1) = CancellablePromise<Void>.pending()
        let (promise2, seal2) = Promise<Void>.pending()
        let (promise3, seal3) = CancellablePromise<Void>.pending()
        
        var finished = false
        when(resolved: promise1, CancellablePromise(promise2), promise3).done(on: nil) { _ in finished = true }.cancel()
        XCTAssertFalse(finished, "Not all promises have resolved")
        
        seal1.fulfill(())
        XCTAssertFalse(finished, "Not all promises have resolved")
        
        seal2.fulfill(())
        XCTAssertFalse(finished, "Not all promises have resolved")
        
        seal3.fulfill(())
        XCTAssert(finished, "All promises have resolved")
    }
}
