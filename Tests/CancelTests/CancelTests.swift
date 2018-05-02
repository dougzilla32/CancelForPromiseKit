//
//  CancellablePromiseKitTests.swift
//  CancellablePromiseKitTests
//
//  Created by Doug Stein on 4/30/18.
//

import XCTest
import CancellablePromiseKit
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
        
        // Test 'cancellableAfter' to ensure it is cancelled
        let cancellableAfterPromise = cancellableAfter(seconds: 0.1)
        cancellableAfterPromise.done {
            XCTFail("cancellableAfter not cancelled")
        }.catch(policy: .allErrorsExceptCancellation) { error in
            XCTFail("cancellableAfterPromise failed with error: \(error)")
        }
        cancellableAfterPromise.cancel()
        
        // Test 'cancellableAfter' to ensure it is cancelled and throws a 'CancellableError'
        let exCancel = expectation(description: "after cancels")
        let cancellableAfterPromiseWithError = cancellableAfter(seconds: 0.1)
        cancellableAfterPromiseWithError.done {
            XCTFail("cancellableAfterWithError not cancelled")
        }.catch(policy: .allErrors) { error in
            exCancel.fulfill()
        }
        cancellableAfterPromiseWithError.cancel()
        
        wait(for: [exComplete, exCancel], timeout: 1)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
