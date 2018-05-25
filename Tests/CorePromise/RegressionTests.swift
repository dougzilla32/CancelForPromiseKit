import PromiseKit
@testable import CancelForPromiseKit
import XCTest

class RegressionTests: XCTestCase {
    func testReturningPreviousPromiseWorks() {

        // regression test because we were doing this wrong
        // in our A+ tests implementation for spec: 2.3.1

        do {
            let promise1 = Promise(cancel: CancelContext())
            let promise2 = promise1.thenCC(on: nil) { promise1 }
            promise2.catchCC(on: nil) { _ in XCTFail() }
            promise1.cancel()
        }
        
        do {
            let ex = expectation(description: "")
            let promise1 = Promise(cancel: CancelContext())
            promise1.cancel()
            let promise2 = promise1.thenCC(on: nil) { () -> Promise<Void> in  XCTFail(); return promise1 }
            promise2.catchCC(on: nil) {
                ex.fulfill()
                print("HI \($0)")
                if !$0.isCancelled {
                    XCTFail()
                }
            }
            wait(for: [ex], timeout: 1)
        }
        
        do {
            enum Error: Swift.Error { case dummy }

            let promise1 = Promise<Void>(cancel: CancelContext(), error: Error.dummy)
            let promise2 = promise1.recoverCC(on: nil) { _ in promise1 }
            promise2.catchCC(on: nil) { err in
                if case PMKError.returnedSelf = err {
                    XCTFail()
                }
            }
            promise1.cancel()
        }
    }
}
