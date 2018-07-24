import PromiseKit
import CancelForPromiseKit
import XCTest

class GuaranteeTests: XCTestCase {
    func testInit() {
        let ex = expectation(description: "")
        CancellableGuarantee { seal in
            seal(1)
        }.done {
            XCTFail()
            XCTAssertEqual(1, $0)
        }.catch(policy: .allErrors) {
            $0.isCancelled ? ex.fulfill() : XCTFail()
        }.cancel()
        wait(for: [ex], timeout: 1)
    }

    func testWait() {
        let ex = expectation(description: "")
        do {
            let p = afterCC(.milliseconds(100)).map(on: nil) { 1 }
            p.cancel()
            let value = try p.wait()
            XCTAssertEqual(value, 1)
        } catch {
            error.isCancelled ? ex.fulfill() : XCTFail()
        }
        wait(for: [ex], timeout: 1)
    }
    
    func testThenMap() {

        let ex = expectation(description: "")

        CancellableGuarantee.valueCC([1, 2, 3])
            .thenMap { CancellableGuarantee.valueCC($0 * 2) }
            .done { values in
                XCTAssertEqual([], values)
                ex.fulfill()
        }.cancel()

        wait(for: [ex], timeout: 1)
    }
}
