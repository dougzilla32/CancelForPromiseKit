import PromiseKit
import CancelForPromiseKit
import Dispatch
import XCTest

class StressTests: XCTestCase {
    func testThenDataRace() {
        let e1 = expectation(description: "")
        let e2 = expectation(description: "")
        var errorCounter = 0

        //will crash if then doesn't protect handlers
        stressDataRace(expectation: e1, iterations: 1000, stressFunction: { promise in
            promise.done { s in
                XCTFail()
                XCTAssertEqual("ok", s)
                return
            }.catch(policy: .allErrors) {
                if !$0.isCancelled {
                    XCTFail()
                }
                errorCounter += 1
                if errorCounter == 1000 {
                    e2.fulfill()
                }
            }.cancel()
        }, fulfill: { "ok" })

        waitForExpectations(timeout: 10, handler: nil)
    }

    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    func testThensAreSequentialForLongTime() {
        var values = [Int]()
        let ex = expectation(description: "")
        let cancelValue = 42
        var promise = DispatchQueue.global().asyncCC(.promise, cancelValue: cancelValue){ 0 }
        let N = 1000
        for x in 1..<N {
            promise = promise.then(cancelValue: cancelValue) { y -> CancellableGuarantee<Int> in
                values.append(y)
                XCTAssertEqual(cancelValue, y)
                return DispatchQueue.global().asyncCC(.promise) { x }
            }
        }
        promise.done { x in
            values.append(x)
            XCTAssertEqual(values, [Int](repeating: cancelValue, count: N))
            ex.fulfill()
        }.cancel()
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testZalgoDataRace() {
        let e1 = expectation(description: "")
        let e2 = expectation(description: "")
        var errorCounter = 0

        //will crash if zalgo doesn't protect handlers
        stressDataRace(expectation: e1, iterations: 1000, stressFunction: { promise in
            promise.done(on: nil) { s in
                XCTAssertEqual("ok", s)
            }.catch(policy: .allErrors) {
                if !$0.isCancelled {
                    XCTFail()
                }
                errorCounter += 1
                if errorCounter == 1000 {
                    e2.fulfill()
                }
            }.cancel()
        }, fulfill: {
            return "ok"
        })

        waitForExpectations(timeout: 10, handler: nil)
    }
}

private enum Error: Swift.Error {
    case Dummy
}

private func stressDataRace<T: Equatable>(expectation e1: XCTestExpectation, iterations: Int = 1000, stressFactor: Int = 10, stressFunction: @escaping (CancellablePromise<T>) -> Void, fulfill f: @escaping () -> T) {
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "the.domain.of.Zalgo", attributes: .concurrent)

    for _ in 0..<iterations {
        let (promise, seal) = CancellablePromise<T>.pending()

        DispatchQueue.concurrentPerform(iterations: stressFactor) { _ in
            stressFunction(promise)
        }

        queue.async(group: group) {
            seal.fulfill(f())
        }
    }

    group.notify(queue: queue, execute: e1.fulfill)
}
