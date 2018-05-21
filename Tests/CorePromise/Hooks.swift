//
//  Hooks.swift
//  CPKCoreTests
//
//  Created by Doug on 5/16/18.
//

import XCTest
import PromiseKit
import CancelForPromiseKit

class CancelHooks {
    static var validate: ((Any, String) -> CancelContext)?
    
    static var checkCancelled: ((CancelContext) throws -> Void)?

    static var append: ((CancelContext, Any) -> Void)?

    static var chain: ((Any, CancelContext) -> Void)?
}

extension Thenable {
    public func thenTest<U: Thenable>(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) throws -> U) -> Promise<U.T> {
        let cc = CancelHooks.validate?(self, "then")
        
        let rp = Promise<U.T>.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    do {
                        if cc != nil {
                            try CancelHooks.checkCancelled?(cc!)
                        }
                        let rv = try body(value)
                        guard rv !== rp.0 else { throw PMKError.returnedSelf }
                        if cc != nil {
                            CancelHooks.append?(cc!, rv)
                        }
                        // Inaccessible: rv.pipe(to: rp.box.seal)
                    } catch {
                        rp.1.reject(error)
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        if cc != nil {
            CancelHooks.chain?(rp.0, cc!)
        }
        return rp.0
    }
    
    public func mapTest<U>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping (T) throws -> U) -> Promise<U> {
        let rp = Promise<U>.pending()
        return rp.0
    }

    public func compactMapTest<U>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping (T) throws -> U?) -> Promise<U> {
        let rp = Promise<U>.pending()
        return rp.0
    }

    public func doneTest(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) throws -> Void) -> Promise<Void> {
        let cc = CancelHooks.validate?(self, "then")
        
        let rp = Promise<Void>.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    do {
                        if cc != nil {
                            try CancelHooks.checkCancelled?(cc!)
                        }
                        try body(value)
                        rp.1.fulfill()
                    } catch {
                        rp.1.reject(error)
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        if cc != nil {
            CancelHooks.chain?(rp.0, cc!)
        }
        return rp.0
    }

    public func getTest(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) throws -> Void) -> Promise<T> {
        let rp = Promise<T>.pending()
        return rp.0
    }

//    public func doneTest(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) -> Void) -> Promise<Void> {
//        let rp = Promise<Void>.pending()
//        return rp.0
//    }

    public func mapTest<U>(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) -> U) -> Promise<U> {
        let rp = Promise<U>.pending()
        return rp.0
    }

    public func thenTest<U>(on: DispatchQueue? = conf.Q.map, _ body: @escaping (T) -> Guarantee<U>) -> Promise<U> {
        let rp = Promise<U>.pending()
        return rp.0
    }
}

extension Optional where Wrapped: DispatchQueue {
    func async(_ body: @escaping() -> Void) {
        switch self {
        case .none:
            body()
        case .some(let q):
            q.async(execute: body)
        }
    }
}

class Scratch: XCTestCase {
    override class func setUp() {
        CancelHooks.validate = { promise, functionName in
            return objc_getAssociatedObject(promise, &CancelContextKey.cancelContext) as! CancelContext
        }
        
        CancelHooks.checkCancelled = { context in
            if let error = context.cancelledError {
                throw error
            }
        }
        
        CancelHooks.append = { context, childPromise in
            if let childContext = objc_getAssociatedObject(childPromise, &CancelContextKey.cancelContext) as? CancelContext {
                context.append(context: childContext)
            }
        }

        CancelHooks.chain = { promise, context in
            objc_setAssociatedObject(promise, &CancelContextKey.cancelContext, context, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
   }
    
    override class func tearDown() {
        CancelHooks.validate = nil
        CancelHooks.checkCancelled = nil
        CancelHooks.append = nil
        CancelHooks.chain = nil
    }
    
    func testExtensionHooks() {
        let exComplete = expectation(description: "test completes")
        
        afterCC(seconds: 0.1).doneTest { value in
            print("hi \(value)")
            exComplete.fulfill()
        }.catchCC(policy: .allErrors) { error in
            print("error \(error)")
        }

        wait(for: [exComplete], timeout: 1)
    }
}
