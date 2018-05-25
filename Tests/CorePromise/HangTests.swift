import PromiseKit
@testable import CancelForPromiseKit
import XCTest

class HangTests: XCTestCase {
    func test() {
        let ex = expectation(description: "block executed")
        do {
            let p = afterCC(seconds: 0.02).thenCC { _ -> Promise<Int> in
                XCTFail()
                return .value(1)
            }
            p.cancel()
            let value = try hangCC(p)
            XCTFail()
            XCTAssertEqual(value, 1)
        } catch {
            error.isCancelled ? ex.fulfill() : XCTFail("Unexpected error")
        }
        waitForExpectations(timeout: 0)
    }

    enum Error: Swift.Error {
        case test
    }

    func testError() {
        var value = 0
        do {
            let p = afterCC(seconds: 0.02).doneCC {
                XCTFail()
                value = 1
                throw Error.test
            }
            p.cancel()
            _ = try hangCC(p)
            XCTFail()
            XCTAssertEqual(value, 1)
        } catch Error.test {
            XCTFail()
        } catch {
            if !error.isCancelled {
                XCTFail("Unexpected error (expected PromiseCancelledError)")
            }
            return
        }
        XCTFail("Expected error but no error was thrown")
    }
}
