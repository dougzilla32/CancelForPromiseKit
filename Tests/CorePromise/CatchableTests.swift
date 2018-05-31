import PromiseKit
import CancelForPromiseKit
import XCTest

class CatchableTests: XCTestCase {

    func testFinally() {
        func helper(error: Error) {
            let ex = (expectation(description: "ex0"), expectation(description: "ex1"))
            var x = 0
            let p = afterCC(seconds: 0.01).catch(policy: .allErrors) { _ in
                XCTAssertEqual(x, 0)
                x += 1
                ex.0.fulfill()
            }.finally {
                XCTAssertEqual(x, 1)
                x += 1
                ex.1.fulfill()
            }

            p.cancel(error: error)

            wait(for: [ex.0, ex.1], timeout: 1)
        }

        helper(error: Error.dummy)
        helper(error: Error.cancelled)
    }

    func testCauterize() {
        let ex = expectation(description: "")
        let p = afterCC(seconds: 0.01)

        // cannot test specifically that this outputs to console,
        // but code-coverage will note that the line is run
        p.cauterize()

        p.catch { _ in
            ex.fulfill()
        }

        p.cancel(error: Error.dummy)

        wait(for: [ex], timeout: 1)
    }
}

// TODO: FIXME!!
/// `Promise<Void>.recover`
extension CatchableTests {
    func fail() { XCTFail() }

    func failInt(_: Int) { XCTFail() }

    func failErr(error: Swift.Error) { XCTFail() }

//    func test__void_specialized_full_recover() {
//
//        func helper(error: Swift.Error) {
//            let ex = expectation(description: "caught")
//            let d = CancellablePromise<Void>(error: error).recover { _ in }.done(failInt)
//            d.catch(policy: .allErrorsExceptCancellation, fail)
//            d.catch(policy: .allErrors, ex.fulfill)
//            d.cancel()
//            wait(for: [ex], timeout: 1)
//        }
//
//        helper(error: Error.dummy)
//        helper(error: Error.cancelled)
//    }
//
//    func test__void_specialized_full_recover__fulfilled_path() {
//        let ex = expectation(description: "")
//        CancellablePromise.pending().promise.recover(failErr).done(failInt).catch(policy: .allErrors, ex.fulfill).cancel()
//        wait(for: [ex], timeout: 1)
//    }
//
//    func test__void_specialized_conditional_recover() {
//        func helper(policy: CatchPolicy, error: Swift.Error, line: UInt = #line) {
//            let ex = expectation(description: "")
//            var x = 0
//            CancellablePromise<Void>(error: error).recover(policy: policy) { (err: Error) -> Void in
//                guard x < 1 else { throw err }
//                x += 1
//            }.done(fail).catch(policy: .allErrors, ex.fulfill).cancel()
//            wait(for: [ex], timeout: 1)
//        }
//
//        for error in [Error.dummy as Swift.Error, Error.cancelled] {
//            helper(policy: .allErrors, error: error)
//        }
//        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
//    }
//
//    func test__void_specialized_conditional_recover__no_recover() {
//
//        func helper(policy: CatchPolicy, error: Error, line: UInt = #line) {
//            let ex = expectation(description: "")
//            CancellablePromise<Void>(error: error).recover(policy: .allErrorsExceptCancellation) { err in
//                throw err
//            }.catch(policy: .allErrors) {
//                $0.isCancelled ? ex.fulfill() : XCTFail()
//            }.cancel()
//            wait(for: [ex], timeout: 1)
//        }
//
//        for error in [Error.dummy, Error.cancelled] {
//            helper(policy: .allErrors, error: error)
//        }
//        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
//    }
//
//    func test__void_specialized_conditional_recover__ignores_cancellation_but_fed_cancellation() {
//        let ex = expectation(description: "")
//        CancellablePromise<Void>(error: Error.cancelled).recover(policy: .allErrorsExceptCancellation) { _ in
//            XCTFail()
//        }.catch(policy: .allErrors) {
//            XCTAssertEqual(Error.cancelled, $0 as? Error)
//            ex.fulfill()
//        }.cancel()
//        wait(for: [ex], timeout: 1)
//    }
//
//    func test__void_specialized_conditional_recover__fulfilled_path() {
//        let ex = expectation(description: "")
//        let p = CancellablePromise.pending().promise.recover { _ in
//            XCTFail()
//        }.catch { _ in
//            XCTFail()   // this `catch` to ensure we are calling the `recover` variant we think we are
//        }.finally {
//            ex.fulfill()
//        }
//        p.cancel()
//        wait(for: [ex], timeout: 1)
//    }
}

/// `Promise<T>.recover`
extension CatchableTests {
    func test__full_recover() {
        func helper(error: Swift.Error) {
            let ex = expectation(description: "")
            CancellablePromise<Int>(error: error).recover { _ in
                return CancellablePromise.value(2)
            }.done { _ in
                XCTFail()
            }.catch(policy: .allErrors, ex.fulfill).cancel()
            wait(for: [ex], timeout: 1)
        }

        helper(error: Error.dummy)
        helper(error: Error.cancelled)
    }

    func test__full_recover__fulfilled_path() {
        let ex = expectation(description: "")
        CancellablePromise.value(1).recover { _ -> CancellablePromise<Int> in
            XCTFail()
            return CancellablePromise.value(2)
        }.done(failInt).catch(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    // TODO: FIXME!!
//    func test__conditional_recover() {
//        func helper(policy: CatchPolicy, error: Swift.Error, line: UInt = #line) {
//            let ex = expectation(description: "\(policy) \(error) \(line)")
//            var x = 0
//            CancellablePromise<Int>(error: error).recover(policy: policy) { err in
//                if policy == .allErrorsExceptCancellation {
//                    XCTFail()
//                }
//                guard x < 1 else { throw err }
//                x += 1
//                return .valueCC(x)
//            }.done { _ in
//                if policy == .allErrorsExceptCancellation {
//                    XCTFail()
//                } else {
//                    ex.fulfill()
//                }
//            }.catch(policy: .allErrors) { error in
//                if policy == .allErrorsExceptCancellation {
//                    error.isCancelled ? ex.fulfill() : XCTFail()
//                } else {
//                    XCTFail()
//                }
//            }.cancel()
//            wait(for: [ex], timeout: 1)
//        }
//
//        for error in [Error.dummy as Swift.Error, Error.cancelled] {
//            helper(policy: .allErrors, error: error)
//        }
//        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
//    }

    func test__conditional_recover__no_recover() {

        func helper(policy: CatchPolicy, error: Error, line: UInt = #line) {
            let ex = expectation(description: "\(policy) \(error) \(line)")
            CancellablePromise<Int>(error: error).recover(policy: policy) { err -> CancellablePromise<Int> in
                throw err
            }.catch(policy: .allErrors) {
                if !($0 is PromiseCancelledError) {
                    XCTAssertEqual(error, $0 as? Error)
                }
                ex.fulfill()
            }.cancel()
            wait(for: [ex], timeout: 1)
        }

        for error in [Error.dummy, Error.cancelled] {
            helper(policy: .allErrors, error: error)
        }
        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
    }

    func test__conditional_recover__ignores_cancellation_but_fed_cancellation() {
        let ex = expectation(description: "")
        CancellablePromise<Int>(error: Error.cancelled).recover(policy: .allErrorsExceptCancellation) { _ -> CancellablePromise<Int> in
            XCTFail()
            return .value(1)
        }.catch(policy: .allErrors) {
            XCTAssertEqual(Error.cancelled, $0 as? Error)
            ex.fulfill()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func test__conditional_recover__fulfilled_path() {
        let ex = expectation(description: "")
        CancellablePromise.value(1).recover { err -> CancellablePromise<Int> in
            XCTFail()
            throw err
        }.done {
            XCTFail()
            XCTAssertEqual($0, 1)
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testEnsureThen_Error() {
        let ex = expectation(description: "")

        let p = CancellablePromise.value(1).done {
            XCTAssertEqual($0, 1)
            throw Error.dummy
        }.ensureThen {
            return afterCC(seconds: 0.01)
        }.catch(policy: .allErrors) {
            XCTAssert($0 is PromiseCancelledError)
        }.finally {
            ex.fulfill()
        }
        p.cancel()

        wait(for: [ex], timeout: 1)
    }

    func testEnsureThen_Value() {
        let ex = expectation(description: "")

        CancellablePromise.value(1).ensureThen {
            afterCC(seconds: 0.01)
        }.done { _ in
            XCTFail()
        }.catch(policy: .allErrors) {
            if !$0.isCancelled {
                XCTFail()
            }
        }.finally {
            ex.fulfill()
        }.cancel()

        wait(for: [ex], timeout: 1)
    }
}

private enum Error: CancellableError {
    case dummy
    case cancelled

    var isCancelled: Bool {
        return self == Error.cancelled
    }
}
