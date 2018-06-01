import PromiseKit
import CancelForPromiseKit
import XCTest

class ThenableTests: XCTestCase {
    func testGet() {
        let ex1 = expectation(description: "")
        CancellablePromise.value(1).get { _ in
            XCTFail()
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex1.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex1], timeout: 1)
    }

    func testCompactMap() {
        let ex = expectation(description: "")
        CancellablePromise.value(1.0).compactMap { _ in
            XCTFail()
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testCompactMapThrows() {

        enum E: Error { case dummy }

        let ex = expectation(description: "")
        let promise = CancellablePromise.value("a")
        promise.compactMap { _ -> Int in
            promise.cancel()
            throw E.dummy
        }.catch(policy: .allErrors) {
            if case E.dummy = $0 {} else {
                XCTFail()
            }
            ex.fulfill()
        }
        wait(for: [ex], timeout: 1)
    }

    func testRejectedPromiseCompactMap() {

        enum E: Error { case dummy }

        let ex = expectation(description: "")
        CancellablePromise(error: E.dummy).compactMap {
            XCTFail()
        }.catch(policy: .allErrors) {
            if case E.dummy = $0 {} else {
                XCTFail()
            }
            ex.fulfill()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testPMKErrorCompactMap() {
        let ex = expectation(description: "")
        CancellablePromise.value("a").compactMap {
            Int($0)
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testCompactMapValues() {
        let ex = expectation(description: "")
        let promise = CancellablePromise.value(["1","2","a","4"])
        promise.compactMapValues {
            Int($0)
        }.done {
            promise.cancel()
            XCTAssertEqual([1,2,4], $0)
            ex.fulfill()
        }.catch(policy: .allErrors) { _ in
            XCTFail()
        }
        wait(for: [ex], timeout: 1)
    }

    func testThenMap() {
        let ex = expectation(description: "")
        let promise = CancellablePromise.value([1,2,3,4])
        promise.thenMap { (x: Int) -> Promise<Int> in
            promise.cancel()
            return Promise.value(x) // Intentionally use 'Promise' rather than 'CancellablePromise'
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }
        wait(for: [ex], timeout: 1)
    }

    func testThenFlatMap() {
        let ex = expectation(description: "")
        CancellablePromise.value([1,2,3,4]).thenFlatMap { (x: Int) -> CancellablePromise<[Int]> in
            XCTFail()
            return CancellablePromise.value([x, x])
        }.done {
            XCTFail()
            XCTAssertEqual([1,1,2,2,3,3,4,4], $0)
            ex.fulfill()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testLastValueForEmpty() {
        XCTAssertTrue(CancellablePromise.value([]).lastValue.isRejected)
    }

    func testFirstValueForEmpty() {
        XCTAssertTrue(CancellablePromise.value([]).firstValue.isRejected)
    }

    func testThenOffRejected() {
        // surprisingly missing in our CI, mainly due to
        // extensive use of `done` in A+ tests since PMK 5

        let ex = expectation(description: "")
        CancellablePromise<Int>(error: PMKError.badInput).then { x -> Promise<Int> in
            XCTFail()
            return .value(x)
        }.catch(policy: .allErrors) {
            if case PMKError.badInput = $0 {} else {
                XCTFail()
            }
            ex.fulfill()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }
}
