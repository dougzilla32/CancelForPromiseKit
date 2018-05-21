import PromiseKit
import CancelForPromiseKit
import XCTest

class GuaranteeTests: XCTestCase {
    func testInit() {
        let ex = expectation(description: "")
        Guarantee(cancel: CancelContext()) { seal in
            seal(1)
        }.doneCC {
            XCTFail()
            XCTAssertEqual(1, $0)
        }.catchCC(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testWait() {
        let ex = expectation(description: "")
        do {
            let p = afterCC(.milliseconds(100)).mapCC(on: nil){ 1 }
            p.cancel()
            let value = try p.wait()
            XCTAssertEqual(value, 1)
        } catch {
            error.isCancelled ? ex.fulfill() : XCTFail()
        }
        wait(for: [ex], timeout: 1)
    }
}
