import Foundation
import PromiseKit
@testable import CancelForPromiseKit
import XCTest

class CancellationTests: XCTestCase {
    func testCancellation() {
        let ex1 = expectation(description: "")

        let p = afterCC(seconds: 0).doneCC { _ in
            XCTFail()
        }
        p.catchCC { _ in
            XCTFail()
        }
        p.catchCC(policy: .allErrors) {
            XCTAssertTrue($0.isCancelled)
            ex1.fulfill()
        }
        
        p.cancel(error: LocalError.cancel)

        waitForExpectations(timeout: 1)
    }

    func testThrowCancellableErrorThatIsNotCancelled() {
        let expect = expectation(description: "")

        let cc = afterCC(seconds: 0).doneCC {
            XCTFail()
        }.catchCC {
            XCTAssertFalse($0.isCancelled)
            expect.fulfill()
        }
        
        cc.cancel(error: LocalError.notCancel)

        waitForExpectations(timeout: 1)
    }

    func testRecoverWithCancellation() {
        let ex1 = expectation(description: "")
        let ex2 = expectation(description: "")

        let p = afterCC(seconds: 0).doneCC { _ in
            XCTFail()
        }.recoverCC(policy: .allErrors) { err -> Promise<Void> in
            ex1.fulfill()
            XCTAssertTrue(err.isCancelled)
            throw err
        }.doneCC { _ in
            XCTFail()
        }
        p.catchCC { _ in
            XCTFail()
        }
        p.catchCC(policy: .allErrors) {
            XCTAssertTrue($0.isCancelled)
            ex2.fulfill()
        }
        
        p.cancel(error: CocoaError.cancelled)

        waitForExpectations(timeout: 1)
    }

    func testFoundationBridging1() {
        let ex = expectation(description: "")

        let p = afterCC(seconds: 0).doneCC { _ in
            XCTFail()
        }
        p.catchCC { _ in
            XCTFail()
        }
        p.catchCC(policy: .allErrors) {
            XCTAssertTrue($0.isCancelled)
            ex.fulfill()
        }

        p.cancel(error: CocoaError.cancelled)
        
        waitForExpectations(timeout: 1)
    }

    func testFoundationBridging2() {
        let ex = expectation(description: "")

        let p = Promise.pendingCC().promise.doneCC {
            XCTFail()
        }
        p.catchCC { _ in
            XCTFail()
        }
        p.catchCC(policy: .allErrors) {
            XCTAssertTrue($0.isCancelled)
            ex.fulfill()
        }
        
        p.cancel(error: URLError.cancelled)

        waitForExpectations(timeout: 1)
    }

#if swift(>=3.2)
    func testIsCancelled() {
        XCTAssertTrue(PMKError.cancelled.isCancelled)
        XCTAssertTrue(URLError.cancelled.isCancelled)
        XCTAssertTrue(CocoaError.cancelled.isCancelled)
        XCTAssertFalse(CocoaError(_nsError: NSError(domain: NSCocoaErrorDomain, code: CocoaError.Code.coderInvalidValue.rawValue)).isCancelled)
    }
#endif
}

private enum LocalError: CancellableError {
    case notCancel
    case cancel

    var isCancelled: Bool {
        switch self {
        case .notCancel: return false
        case .cancel: return true
        }
    }
}

private extension URLError {
    static var cancelled: URLError {
        return .init(_nsError: NSError(domain: NSURLErrorDomain, code: URLError.Code.cancelled.rawValue))
    }
}

private extension CocoaError {
    static var cancelled: CocoaError {
        return .init(_nsError: NSError(domain: NSCocoaErrorDomain, code: CocoaError.Code.userCancelled.rawValue))
    }
}
