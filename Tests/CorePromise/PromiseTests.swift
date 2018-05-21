import PromiseKit
import CancelForPromiseKit
import Dispatch
import XCTest

class PromiseTests: XCTestCase {
    func testIsPending() {
        XCTAssertTrue(Promise<Void>.pendingCC().promise.isPending)
        XCTAssertFalse(Promise(cancel: CancelContext()).isPending)
        XCTAssertFalse(Promise<Void>(cancel: CancelContext(), error: Error.dummy).isPending)
    }

    func testIsResolved() {
        XCTAssertFalse(Promise<Void>.pending().promise.isResolved)
        XCTAssertTrue(Promise(cancel: CancelContext()).isResolved)
        XCTAssertTrue(Promise<Void>(error: Error.dummy).isResolved)
    }

    func testIsFulfilled() {
        XCTAssertFalse(Promise<Void>.pendingCC().promise.isFulfilled)
        XCTAssertTrue(Promise(cancel: CancelContext()).isFulfilled)
        XCTAssertFalse(Promise<Void>(cancel: CancelContext(), error: Error.dummy).isFulfilled)
    }

    func testIsRejected() {
        XCTAssertFalse(Promise<Void>.pendingCC().promise.isRejected)
        XCTAssertTrue(Promise<Void>(cancel: CancelContext(), error: Error.dummy).isRejected)
        XCTAssertFalse(Promise(cancel: CancelContext()).isRejected)
    }

    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    func testDispatchQueueAsyncExtensionReturnsPromise() {
        let ex = expectation(description: "")

        DispatchQueue.global().asyncCC(.promise) { () -> Int in
            usleep(100000)
            XCTAssertFalse(Thread.isMainThread)
            return 1
        }.doneCC { one in
            XCTFail()
            XCTAssertEqual(one, 1)
        }.catchCC(policy: .allErrors) {
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
        }.doneCC { _ in
            XCTFail()
        }.catchCC {
            $0.isCancelled ? XCTFail() : ex.fulfill()
        }.cancel()

        waitForExpectations(timeout: 1)
    }

    func testCustomStringConvertible() {
        XCTAssertEqual(Promise<Int>.pendingCC().promise.debugDescription, "Promise<Int>.pending(handlers: 0)")
        XCTAssertEqual(Promise(cancel: CancelContext()).debugDescription, "Promise<()>.fulfilled(())")
        XCTAssertEqual(Promise<String>(cancel: CancelContext(), error: Error.dummy).debugDescription, "Promise<String>.rejected(Error.dummy)")

        XCTAssertEqual("\(Promise<Int>.pendingCC().promise)", "Promise(…Int)")
        XCTAssertEqual("\(Promise.valueCC(3))", "Promise(3)")
        XCTAssertEqual("\(Promise<Void>(cancel: CancelContext(), error: Error.dummy))", "Promise(dummy)")
    }

    func testCannotFulfillWithError() {

        // sadly this test proves the opposite :(
        // left here so maybe one day we can prevent instantiation of `Promise<Error>`

        _ = Promise(cancel: CancelContext()) { seal in
            seal.fulfill(Error.dummy)
        }

        _ = Promise<Error>.pendingCC()

        _ = Promise.valueCC(Error.dummy)

        _ = Promise(cancel: CancelContext()).mapCC { Error.dummy }
    }

#if swift(>=3.1)
    func testCanMakeVoidPromise() {
        _ = Promise(cancel: CancelContext())
        _ = Guarantee(cancel: CancelContext())
    }
#endif

    enum Error: Swift.Error {
        case dummy
    }

    func testThrowInInitializer() {
        let p = Promise<Void>(cancel: CancelContext()) { _ in
            throw Error.dummy
        }
        p.cancel()
        XCTAssertTrue(p.isRejected)
        guard let err = p.error, case Error.dummy = err else { return XCTFail() }
    }

    func testThrowInFirstly() {
        let ex = expectation(description: "")

        firstlyCC { () -> Promise<Int> in
            throw Error.dummy
        }.catchCC {
            XCTAssertEqual($0 as? Error, Error.dummy)
            ex.fulfill()
        }.cancel()

        wait(for: [ex], timeout: 1)
    }

    func testWait() throws {
        let p = afterCC(.milliseconds(100)).thenCC(on: nil){ Promise.valueCC(1) }
        p.cancel()
        do {
            _ = try p.wait()
            XCTFail()
        } catch {
            XCTAssert(error.isCancelled)
        }

        do {
            let p = afterCC(.milliseconds(100)).mapCC(on: nil){ throw Error.dummy }
            p.cancel()
            try p.wait()
            XCTFail()
        } catch {
            XCTAssert(error.isCancelled)
        }
    }

    func testPipeForResolved() {
        let ex = expectation(description: "")
        Promise.valueCC(1).doneCC {
            XCTFail()
            XCTAssertEqual(1, $0)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail("\($0)")
        }.cancel()
        wait(for: [ex], timeout: 1)
    }
}
