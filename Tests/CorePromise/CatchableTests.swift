import PromiseKit
@testable import CancelForPromiseKit
import XCTest

class CatchableTests: XCTestCase {

    func testFinally() {
        func helper(error: Error) {
            let ex = (expectation(description: "ex0"), expectation(description: "ex1"))
            var x = 0
            let p = afterCC(seconds: 0.01).catchCC(policy: .allErrors) { _ in
                XCTAssertEqual(x, 0)
                x += 1
                ex.0.fulfill()
            }.finallyCC {
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

/// `Promise<Void>.recover`
extension CatchableTests {
    func fail() { XCTFail() }

    func fail(_: Int) { XCTFail() }
    
    func fail(error: Swift.Error) { XCTFail() }

    func test__void_specialized_full_recover() {

        func helper(error: Swift.Error) {
            let ex = expectation(description: "caught")
            let d = Promise<Void>(cancel: CancelContext(), error: error).recoverCC { _ in }.doneCC(fail)
            d.catchCC(policy: .allErrorsExceptCancellation, fail)
            d.catchCC(policy: .allErrors, ex.fulfill)
            d.cancel()
            wait(for: [ex], timeout: 1)
        }

        helper(error: Error.dummy)
        helper(error: Error.cancelled)
    }

    func test__void_specialized_full_recover__fulfilled_path() {
        let ex = expectation(description: "")
        Promise.pendingCC().promise.recoverCC(fail).doneCC(fail).catchCC(policy: .allErrors, ex.fulfill).cancel()
        wait(for: [ex], timeout: 1)
    }

    func test__void_specialized_conditional_recover() {
        func helper(policy: CatchPolicy, error: Swift.Error, line: UInt = #line) {
            let ex = expectation(description: "")
            var x = 0
            Promise<Void>(cancel: CancelContext(), error: error).recoverCC(policy: policy) { err in
                guard x < 1 else { throw err }
                x += 1
            }.doneCC(fail).catchCC(policy: .allErrors, ex.fulfill).cancel()
            wait(for: [ex], timeout: 1)
        }

        for error in [Error.dummy as Swift.Error, Error.cancelled] {
            helper(policy: .allErrors, error: error)
        }
        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
    }

    func test__void_specialized_conditional_recover__no_recover() {

        func helper(policy: CatchPolicy, error: Error, line: UInt = #line) {
            let ex = expectation(description: "")
            Promise<Void>(cancel: CancelContext(), error: error).recoverCC(policy: .allErrorsExceptCancellation) { err in
                throw err
            }.catchCC(policy: .allErrors) {
                $0.isCancelled ? ex.fulfill() : XCTFail()
            }.cancel()
            wait(for: [ex], timeout: 1)
        }

        for error in [Error.dummy, Error.cancelled] {
            helper(policy: .allErrors, error: error)
        }
        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
    }

    func test__void_specialized_conditional_recover__ignores_cancellation_but_fed_cancellation() {
        let ex = expectation(description: "")
        Promise<Void>(cancel: CancelContext(), error: Error.cancelled).recoverCC(policy: .allErrorsExceptCancellation) { _ in
            XCTFail()
        }.catchCC(policy: .allErrors) {
            XCTAssertEqual(Error.cancelled, $0 as? Error)
            ex.fulfill()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func test__void_specialized_conditional_recover__fulfilled_path() {
        let ex = expectation(description: "")
        let p = Promise.pendingCC().promise.recoverCC { _ in
            XCTFail()
        }.catchCC { _ in
            XCTFail()   // this `catch` to ensure we are calling the `recover` variant we think we are
        }.finallyCC {
            ex.fulfill()
        }
        p.cancel()
        wait(for: [ex], timeout: 1)
    }
}

/// `Promise<T>.recover`
extension CatchableTests {
    func test__full_recover() {
        func helper(error: Swift.Error) {
            let ex = expectation(description: "")
            Promise<Int>(cancel: CancelContext(), error: error).recoverCC { _ in
                return Promise.valueCC(2)
            }.doneCC { _ in
                XCTFail()
            }.catchCC(policy: .allErrors, ex.fulfill).cancel()
            wait(for: [ex], timeout: 1)
        }

        helper(error: Error.dummy)
        helper(error: Error.cancelled)
    }

    func test__full_recover__fulfilled_path() {
        let ex = expectation(description: "")
        Promise.valueCC(1).recoverCC { _ -> Promise<Int> in
            XCTFail()
            return Promise.valueCC(2)
        }.doneCC(fail).catchCC(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func test__conditional_recover() {
        func helper(policy: CatchPolicy, error: Swift.Error, line: UInt = #line) {
            let ex = expectation(description: "\(policy) \(error) \(line)")
            var x = 0
            Promise<Int>(cancel: CancelContext(), error: error).recoverCC(policy: policy) { err -> Promise<Int> in
                if policy == .allErrorsExceptCancellation {
                    XCTFail()
                }
                guard x < 1 else { throw err }
                x += 1
                return .valueCC(x)
            }.doneCC { _ in
                (policy == .allErrorsExceptCancellation) ? XCTFail() : ex.fulfill()
            }.catchCC(policy: .allErrors) { error in
                if policy == .allErrorsExceptCancellation {
                    error.isCancelled ? ex.fulfill() : XCTFail()
                } else {
                    XCTFail()
                }
            }.cancel()
            wait(for: [ex], timeout: 1)
        }

        for error in [Error.dummy as Swift.Error, Error.cancelled] {
            helper(policy: .allErrors, error: error)
        }
        helper(policy: .allErrorsExceptCancellation, error: Error.dummy)
    }

    func test__conditional_recover__no_recover() {

        func helper(policy: CatchPolicy, error: Error, line: UInt = #line) {
            let ex = expectation(description: "\(policy) \(error) \(line)")
            Promise<Int>(cancel: CancelContext(), error: error).recoverCC(policy: policy) { err -> Promise<Int> in
                throw err
            }.catchCC(policy: .allErrors) {
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
        Promise<Int>(cancel: CancelContext(), error: Error.cancelled).recoverCC(policy: .allErrorsExceptCancellation) { _ -> Promise<Int> in
            XCTFail()
            return .value(1)
        }.catchCC(policy: .allErrors) {
            XCTAssertEqual(Error.cancelled, $0 as? Error)
            ex.fulfill()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func test__conditional_recover__fulfilled_path() {
        let ex = expectation(description: "")
        Promise.valueCC(1).recoverCC { err -> Promise<Int> in
            XCTFail()
            throw err
        }.doneCC {
            XCTFail()
            XCTAssertEqual($0, 1)
        }.catchCC(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testEnsureThen_Error() {
        let ex = expectation(description: "")

        let p = Promise.valueCC(1).doneCC {
            print("DONE")
            XCTAssertEqual($0, 1)
            throw Error.dummy
        }.ensureThenCC {
            print("ENSURE THEN")
            return afterCC(seconds: 0.01)
        }.catchCC(policy: .allErrors) {
            print("CATCH")
            XCTAssert($0 is PromiseCancelledError)
        }.finallyCC {
            print("FINALLY")
            ex.fulfill()
        }
        print("CANCEL")
        p.cancel()

        wait(for: [ex], timeout: 1)
    }

    func testEnsureThen_Value() {
        let ex = expectation(description: "")

        Promise.valueCC(1).ensureThenCC {
            afterCC(seconds: 0.01)
        }.doneCC { _ in
            XCTFail()
        }.catchCC(policy: .allErrors) {
            if !$0.isCancelled {
                XCTFail()
            }
        }.finallyCC {
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
