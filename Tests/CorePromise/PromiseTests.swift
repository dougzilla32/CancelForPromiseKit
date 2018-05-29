import PromiseKit
import CancelForPromiseKit
import Dispatch
import XCTest

class PromiseTests: XCTestCase {
    func testIsPending() {
        XCTAssertTrue(CancellablePromise<Void>.pending().promise.promise.isPending)
        XCTAssertFalse(CancellablePromise().promise.isPending)
        XCTAssertFalse(CancellablePromise<Void>(error: Error.dummy).promise.isPending)
    }

    func testIsResolved() {
        XCTAssertFalse(CancellablePromise<Void>.pending().promise.promise.isResolved)
        XCTAssertTrue(CancellablePromise().promise.isResolved)
        XCTAssertTrue(CancellablePromise<Void>(error: Error.dummy).promise.isResolved)
    }

    func testIsFulfilled() {
        XCTAssertFalse(CancellablePromise<Void>.pending().promise.promise.isFulfilled)
        XCTAssertTrue(CancellablePromise().promise.isFulfilled)
        XCTAssertFalse(CancellablePromise<Void>(error: Error.dummy).promise.isFulfilled)
    }

    func testIsRejected() {
        XCTAssertFalse(CancellablePromise<Void>.pending().promise.promise.isRejected)
        XCTAssertTrue(CancellablePromise<Void>(error: Error.dummy).promise.isRejected)
        XCTAssertFalse(CancellablePromise().promise.isRejected)
    }

    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    func testDispatchQueueAsyncExtensionReturnsPromise() {
        let ex = expectation(description: "")

        DispatchQueue.global().asyncCC(.promise) { () -> Int in
            usleep(100000)
            XCTAssertFalse(Thread.isMainThread)
            return 1
        }.done { one in
            XCTFail()
            XCTAssertEqual(one, 1)
        }.catch(policy: .allErrors) {
            print($0)
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()

        waitForExpectations(timeout: 1)
    }

    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    func testDispatchQueueAsyncExtensionCanThrowInBody() {
        let ex = expectation(description: "")

        DispatchQueue.global().asyncCC(.promise) { () -> Int in
            throw Error.dummy
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            $0.isCancelled ? XCTFail() : ex.fulfill()
        }.cancel()

        waitForExpectations(timeout: 1)
    }

    func testCustomStringConvertible() {
        XCTAssertEqual(CancellablePromise<Int>.pending().promise.promise.debugDescription, "Promise<Int>.pending(handlers: 0)")
        XCTAssertEqual(CancellablePromise().promise.debugDescription, "Promise<()>.fulfilled(())")
        XCTAssertEqual(CancellablePromise<String>(error: Error.dummy).promise.debugDescription, "Promise<String>.rejected(Error.dummy)")

        XCTAssertEqual("\(CancellablePromise<Int>.pending().promise.promise)", "Promise(…Int)")
        XCTAssertEqual("\(CancellablePromise.value(3).promise)", "Promise(3)")
        XCTAssertEqual("\(CancellablePromise<Void>(error: Error.dummy).promise)", "Promise(dummy)")
    }

    func testCannotFulfillWithError() {

        // sadly this test proves the opposite :(
        // left here so maybe one day we can prevent instantiation of `CancellablePromise<Error>`

        _ = CancellablePromise { seal in
            seal.fulfill(Error.dummy)
        }

        _ = CancellablePromise<Error>.pending()

        _ = CancellablePromise.value(Error.dummy)

        _ = CancellablePromise().map { Error.dummy }
    }

#if swift(>=3.1)
    func testCanMakeVoidPromise() {
        _ = CancellablePromise()
        _ = Guarantee()
    }
#endif

    enum Error: Swift.Error {
        case dummy
    }

    func testThrowInInitializer() {
        let p = CancellablePromise<Void> { _ in
            throw Error.dummy
        }
        p.cancel()
        XCTAssertTrue(p.promise.isRejected)
        guard let err = p.promise.error, case Error.dummy = err else { return XCTFail() }
    }

    func testThrowInFirstly() {
        let ex = expectation(description: "")

        firstly { () -> CancellablePromise<Int> in
            throw Error.dummy
        }.catch {
            XCTAssertEqual($0 as? Error, Error.dummy)
            ex.fulfill()
        }.cancel()

        wait(for: [ex], timeout: 1)
    }

    func testWait() throws {
        let p = afterCC(.milliseconds(100)).then(on: nil){ CancellablePromise.value(1) }
        p.cancel()
        do {
            _ = try p.wait()
            XCTFail()
        } catch {
            XCTAssert(error.isCancelled)
        }

        do {
            let p = afterCC(.milliseconds(100)).map(on: nil){ throw Error.dummy }
            p.cancel()
            try p.wait()
            XCTFail()
        } catch {
            XCTAssert(error.isCancelled)
        }
    }

    func testPipeForResolved() {
        let ex = expectation(description: "")
        CancellablePromise.value(1).done {
            XCTFail()
            XCTAssertEqual(1, $0)
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail("\($0)")
        }.cancel()
        wait(for: [ex], timeout: 1)
    }
}
