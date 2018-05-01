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
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")
        Promise.value(1).get {
            XCTAssertEqual($0, 1)
            ex1.fulfill()
        }.done {
            XCTAssertEqual($0, 1)
            ex2.fulfill()
        }.catch { error in
            XCTFail("Error: \(error)")
        }
        wait(for: [ex1, ex2], timeout: 10)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
