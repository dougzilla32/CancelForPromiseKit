import XCTest
import PromiseKit
@testable import CancelForPromiseKit

class RaceTests: XCTestCase {
    func test1() {
        let ex = expectation(description: "")
        let after1 = afterCC(.milliseconds(10), cancel: CancelContext())
        let after2 = afterCC(seconds: 1, cancel: CancelContext())
        raceCC(after1.thenCC{ Promise.valueCC(1) }, after2.mapCC{ 2 }).doneCC { index in
            XCTFail()
            XCTAssertEqual(index, 1)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        XCTAssert(after1.isCancelled)
        XCTAssert(after2.isCancelled)
        XCTAssert(after1.cancelAttempted)
        XCTAssert(after2.cancelAttempted)
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func test2() {
        let ex = expectation(description: "")
        let after1 = afterCC(seconds: 1, cancel: CancelContext()).mapCC{ 1 }
        let after2 = afterCC(.milliseconds(10), cancel: CancelContext()).mapCC{ 2 }
        raceCC(after1, after2).doneCC { index in
            XCTFail()
            XCTAssertEqual(index, 2)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        XCTAssert(after1.isCancelled)
        XCTAssert(after2.isCancelled)
        XCTAssert(after1.cancelAttempted)
        XCTAssert(after2.cancelAttempted)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func test1Array() {
        let ex = expectation(description: "")
        let promises = [afterCC(.milliseconds(10), cancel: CancelContext()).mapCC{ 1 }, afterCC(seconds: 1, cancel: CancelContext()).mapCC{ 2 }]
        raceCC(promises).doneCC { index in
            XCTAssertEqual(index, 1)
            ex.fulfill()
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        for p in promises {
            XCTAssert(p.cancelAttempted)
            XCTAssert(p.isCancelled)
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func test2Array() {
        let ex = expectation(description: "")
        let after1 = afterCC(seconds: 1, cancel: CancelContext()).mapCC{ 1 }
        let after2 = afterCC(.milliseconds(10), cancel: CancelContext()).mapCC{ 2 }
        raceCC(after1, after2).doneCC { index in
            XCTFail()
            XCTAssertEqual(index, 2)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        XCTAssert(after1.isCancelled)
        XCTAssert(after2.isCancelled)
        XCTAssert(after1.cancelAttempted)
        XCTAssert(after2.cancelAttempted)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testEmptyArray() {
        let ex = expectation(description: "")
        let empty = [Promise<Int>]()
        raceCC(empty).catchCC {
            guard case PMKError.badInput = $0 else { return XCTFail() }
            ex.fulfill()
        }
        wait(for: [ex], timeout: 1)
    }
}
