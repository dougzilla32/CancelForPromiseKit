import PromiseKit
import CancelForPromiseKit
import XCTest

class CPKErrorTests: XCTestCase {
    func testCustomStringConvertible() {
        XCTAssertNotNil(PromiseCancelledError().errorDescription)
    }

    func testCustomDebugStringConvertible() {
        XCTAssertNotNil(PromiseCancelledError().debugDescription.isEmpty)
    }
}
