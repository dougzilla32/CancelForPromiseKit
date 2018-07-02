import CPKFoundation
import Foundation
import CancelForPromiseKit
import XCTest

// Workaround for error with missing libswiftContacts.dylib, this import causes the
// library to be included as needed
#if os(iOS) || os(watchOS) || os(OSX)
import class Contacts.CNPostalAddress
#endif

#if os(macOS)

class NSTaskTests: XCTestCase {
    func test1() {
        let ex = expectation(description: "")
        let task = Process()
        task.launchPath = "/usr/bin/man"
        task.arguments = ["ls"]
        
        let context = task.launchCC(.promise).done { stdout, _ in
            let stdout = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            XCTAssertEqual(stdout, "bar\n")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail("Error: \(error)")
        }.cancelContext
        context.cancel()
        waitForExpectations(timeout: 3)
    }

    func test2() {
        let ex = expectation(description: "")
        let dir = "/usr/bin"

        let task = Process()
        task.launchPath = "/bin/ls"
        task.arguments = ["-l", dir]

        let context = task.launchCC(.promise).done { _ in
            XCTFail("failed to cancel process")
        }.catch(policy: .allErrors) { error in
            error.isCancelled ? ex.fulfill() : XCTFail("unexpected error \(error)")
        }.cancelContext
        context.cancel()
        waitForExpectations(timeout: 3)
    }
}

#endif
