//
//  CancelChain.swift
//  CPKCoreTests
//
//  Created by Doug Stein on 5/16/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

class CancelChain: XCTestCase {
    // Using a distinct type for each promise so we can tell which promise is which when using trace messages inside Thenable
    struct A { }
    struct B { }
    struct C { }
    struct D { }
    struct E { }
    
    struct Chain {
        let pA: CancellablePromise<A>
        let pB: CancellablePromise<B>
        let pC: CancellablePromise<C>
        let pD: CancellablePromise<D>
        let pE: CancellablePromise<E>
    }
    
    func trace(_ message: String) {
        // print(message)
    }
    
    func cancelChainPromises() -> Chain {
        let pA = CancellablePromise<A> { seal in
            self.trace("A IN")
            afterCC(seconds: 0.05).done {
                self.trace("A FULFILL")
                seal.fulfill(A())
            }.catch(policy: .allErrors) {
                self.trace("A ERR")
                seal.reject($0)
            }
        }
        
        let pB = CancellablePromise<B> { seal in
            self.trace("B IN")
            afterCC(seconds: 0.1).done {
                self.trace("B FULFILL")
                seal.fulfill(B())
            }.catch(policy: .allErrors) {
                self.trace("B ERR")
                seal.reject($0)
            }
        }
        
        let pC = CancellablePromise<C> { seal in
            self.trace("C IN")
            afterCC(seconds: 0.15).done {
                self.trace("C FULFILL")
                seal.fulfill(C())
           }.catch(policy: .allErrors) {
                self.trace("C ERR")
                seal.reject($0)
            }
        }
        
        let pD = CancellablePromise<D> { seal in
            self.trace("D IN")
            afterCC(seconds: 0.2).done {
                self.trace("D FULFILL")
                seal.fulfill(D())
            }.catch(policy: .allErrors) {
                self.trace("D ERR")
                seal.reject($0)
            }
        }
        
        let pE = CancellablePromise<E> { seal in
            self.trace("E IN")
            afterCC(seconds: 0.25).done {
                self.trace("E FULFILL")
                seal.fulfill(E())
            }.catch(policy: .allErrors) {
                self.trace("E ERR")
                seal.reject($0)
            }
        }
        
        return Chain(pA: pA, pB: pB, pC: pC, pD: pD, pE: pE)
    }
    
    struct exABCDE {
        let a: XCTestExpectation?
        let b: XCTestExpectation?
        let c: XCTestExpectation?
        let d: XCTestExpectation?
        let e: XCTestExpectation?
        let cancelled: XCTestExpectation?
    }
    
    func cancelChainSetup(waitTime: TimeInterval, ex: exABCDE) {
        {
            let c = cancelChainPromises()
        
            c.pA.then { (_: A) -> CancellablePromise<A> in
                self.trace("pA.then")
                return firstly { () -> CancellablePromise<B> in
                    self.trace("pB.firstly")
                    return c.pB
                }.then { (_: B) -> CancellablePromise<D> in
                    self.trace("pB.then")
                    return firstly { () -> CancellablePromise<C> in
                        self.trace("pC.firstly")
                        ex.b?.fulfill() ?? XCTFail("pB.thenCC")
                        return c.pC
                    }.then { (_: C) -> CancellablePromise<D> in
                        ex.c?.fulfill() ?? XCTFail("pC.thenCC")
                        self.trace("pC.then")
                        return c.pD
                    }
                }.then { (_: D) -> CancellablePromise<A> in
                    ex.d?.fulfill() ?? XCTFail("pD.doneCC")
                    return c.pA  // Intentional reuse of pA -- causes a loop that CancelContext must detect
                }
            }.then { (_: A) -> CancellablePromise<E> in
                self.trace("pA.then")
                ex.a?.fulfill() ?? XCTFail("pA completed")
                return c.pE
            }.done { _ in
                ex.e?.fulfill() ?? XCTFail("pE completed")
                self.trace("pE.done")
            }.catch(policy: .allErrors) {
                self.trace("Error: \($0)")
                $0.isCancelled ? ex.cancelled?.fulfill() : print("Error: \($0)")
            }
        
            self.trace("SETUP COMPLETE")
            
            let exCancelCalled = expectation(description: "cancel called")
            after(seconds: waitTime).done {
                self.trace("CANCEL")
                c.pA.cancel()
                exCancelCalled.fulfill()
            }
            
            let expectations = [ex.a, ex.b, ex.c, ex.d, ex.e, ex.cancelled].compactMap { $0 }
            wait(for: expectations, timeout: 1)
            
            if ex.cancelled == nil {
                XCTAssert(!(c.pA.cancelContext?.cancelAttempted ?? true))
                XCTAssert(!(c.pB.cancelContext?.cancelAttempted ?? true))
                XCTAssert(!(c.pC.cancelContext?.cancelAttempted ?? true))
                XCTAssert(!(c.pD.cancelContext?.cancelAttempted ?? true))
                XCTAssert(!(c.pE.cancelContext?.cancelAttempted ?? true))
            } else {
                XCTAssert(c.pA.cancelContext?.cancelAttempted ?? false)
                XCTAssert(ex.a == nil || isFulfilled(c.pB) || c.pB.cancelContext?.cancelAttempted ?? false)
                XCTAssert(ex.b == nil || isFulfilled(c.pC) || c.pC.cancelContext?.cancelAttempted ?? false)
                XCTAssert(ex.c == nil || isFulfilled(c.pD) || c.pD.cancelContext?.cancelAttempted ?? false)
                XCTAssert(ex.d == nil || isFulfilled(c.pE) || c.pE.cancelContext?.cancelAttempted ?? false)
            }
            
            wait(for: [exCancelCalled], timeout: 1)
        }()
        
        self.trace("DONE")

        return
    }
    
    func isFulfilled<T>(_ p: CancellablePromise<T>) -> Bool {
        if let result = p.promise.result {
            if case .fulfilled = result {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    func testCancelChainPB() {
        let ex = exABCDE(a: nil,
                         b: expectation(description: "pB completed"),
                         c: nil,
                         d: nil,
                         e: nil,
                         cancelled: expectation(description: "cancelled"))
        cancelChainSetup(waitTime: 0.125, ex: ex)
    }

    func testCancelChainPC() {
        let ex = exABCDE(a: nil,
                         b: expectation(description: "pB completed"),
                         c: expectation(description: "pC completed"),
                         d: nil,
                         e: nil,
                         cancelled: expectation(description: "cancelled"))
        cancelChainSetup(waitTime: 0.175, ex: ex)
    }

    func testCancelChainPAD() {
        let ex = exABCDE(a: expectation(description: "pB completed"),
                         b: expectation(description: "pB completed"),
                         c: expectation(description: "pC completed"),
                         d: expectation(description: "pD completed"),
                         e: nil,
                         cancelled: expectation(description: "cancelled"))
        cancelChainSetup(waitTime: 0.225, ex: ex)
    }

    func testCancelChainSuccess() {
        let ex = exABCDE(a: expectation(description: "pA completed"),
                         b: expectation(description: "pB completed"),
                         c: expectation(description: "pC completed"),
                         d: expectation(description: "pD completed"),
                         e: expectation(description: "pE completed"),
                         cancelled: nil)
        cancelChainSetup(waitTime: 0.5, ex: ex)
    }
}
