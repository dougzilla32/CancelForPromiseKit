import PromiseKit
import CancelForPromiseKit
import XCTest

class RegressionTests: XCTestCase {
    func testReturningPreviousPromiseWorks() {

        // regression test because we were doing this wrong
        // in our A+ tests implementation for spec: 2.3.1

        do {
            let promise1 = CancellablePromise()
            let promise2 = promise1.then(on: nil) { promise1 }
            promise2.catch(on: nil) { _ in XCTFail() }
            promise1.cancel()
        }
        
        do {
            let ex = expectation(description: "")
            let promise1 = CancellablePromise()
            promise1.cancel()
            let promise2 = promise1.then(on: nil) { () -> CancellablePromise<Void> in  XCTFail(); return promise1 }
            promise2.catch(on: nil) {
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

            let promise1 = CancellablePromise<Void>(error: Error.dummy)
            let promise2 = promise1.recover(on: nil) { _ in promise1 }
            promise2.catch(on: nil) { err in
                if case PMKError.returnedSelf = err {
                    XCTFail()
                }
            }
            promise1.cancel()
        }
    }
}
