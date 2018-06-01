//
//  CancellableCatchable.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/10/18.
//

import Dispatch
import PromiseKit

public protocol CancellableCatchMixin: CancellableThenable {
    associatedtype M: CatchMixin

    var catchable: M { get }
}

public extension CancellableCatchMixin {
    @discardableResult
    func `catch`(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, _ body: @escaping(Error) -> Void) -> CPKFinalizer {
        return CPKFinalizer(self.catchable.catch(on: on, policy: policy, body), cancel: self.cancelContext)
    }
}

public class CPKFinalizer {
    let pmkFinalizer: PMKFinalizer
    public let cancelContext: CancelContext
    
    init(_ pmkFinalizer: PMKFinalizer, cancel: CancelContext) {
        self.pmkFinalizer = pmkFinalizer
        self.cancelContext = cancel
    }
    
    /// `finally` is the same as `ensure`, but it is not chainable
    @discardableResult
    public func finally(_ body: @escaping () -> Void) -> CancelContext {
        pmkFinalizer.finally(body)
        return cancelContext
    }
    
    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelContext.cancel(error: error, file: file, function: function, line: line)
    }
    
    public var isCancelled: Bool {
        return cancelContext.isCancelled
    }
    
    public var cancelAttempted: Bool {
        return cancelContext.cancelAttempted
    }
    
    public var cancelledError: Error? {
        return cancelContext.cancelledError
    }
}

public extension CancellableCatchMixin {
    func recover<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, _ body: @escaping(Error) throws -> V) -> CancellablePromise<M.T> where V.U.T == M.T {
        
        let description = PromiseDescription<V.U.T>()
        let cancelItems = CancelItemList()
        
        let cancelBody = { (error: Error) throws -> V.U in
            if let cancelledError = self.cancelContext.cancelledError {
                if policy == .allErrorsExceptCancellation {
                    throw cancelledError
                } else {
                    self.cancelContext.recover()
                }
            }
            
            self.cancelContext.removeItems(self.cancelItems, clearList: true)
            
            let rv = try body(error)
            self.cancelContext.append(context: rv.cancelContext, description: description, cancelItems: cancelItems)
            return rv.thenable
        }
        
        let promise = self.catchable.recover(on: on, policy: policy, cancelBody)
        description.promise = promise
        return CancellablePromise(promise, context: self.cancelContext, cancelItems: cancelItems)
    }
    
    func ensure(on: DispatchQueue? = conf.Q.return, _ body: @escaping () -> Void) -> CancellablePromise<M.T> {
        let rp = CancellablePromise<M.T>.pending()
        rp.promise.cancelContext = self.cancelContext
        self.catchable.pipe { result in
            on.async {
                body()
                switch result {
                case .fulfilled(let value):
                    if let error = self.cancelContext.cancelledError {
                        rp.resolver.reject(error)
                    } else {
                        rp.resolver.fulfill(value)
                    }
                case .rejected(let error):
                    rp.resolver.reject(error)
                }
            }
        }
        return rp.promise
    }
    
    func ensureThen(on: DispatchQueue? = conf.Q.return, _ body: @escaping () -> CancellablePromise<Void>) -> CancellablePromise<M.T> {
        let rp = CancellablePromise<M.T>.pending()
        rp.promise.cancelContext = cancelContext
        self.catchable.pipe { result in
            on.async {
                let rv = body()
                rp.promise.appendCancelContext(from: rv)
                
                rv.done {
                    switch result {
                    case .fulfilled(let value):
                        if let error = self.cancelContext.cancelledError {
                            rp.resolver.reject(error)
                        } else {
                            rp.resolver.fulfill(value)
                        }
                    case .rejected(let error):
                        rp.resolver.reject(error)
                    }
                }.catch(policy: .allErrors) {
                    rp.resolver.reject($0)
                }
            }
        }
        return rp.promise
    }
    
    func cauterize() {
        self.catch(policy: .allErrors) {
            Swift.print("CancelForPromiseKit:cauterized-error:", $0)
        }
    }
}

public extension CancellableCatchMixin where M.T == Void {
    /**
     The provided closure executes when this promise rejects.
     
     This variant of `recover` is specialized for `Void` promises and de-errors your chain returning a `Guarantee`, thus you cannot `throw` and you must handle all errors including cancellation.
     
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The handler to execute if this promise is rejected.
     - SeeAlso: [Cancellation](http://promisekit.org/docs/)
     */
    @discardableResult
    func recover(on: DispatchQueue? = conf.Q.map, _ body: @escaping(Error) -> Void) -> CancellableGuarantee<Void> {
        let guarantee: Guarantee<Void> = self.catchable.recover(on: on, body)
        return CancellableGuarantee(guarantee, context: self.cancelContext)
    }
    
    /**
     The provided closure executes when this promise rejects.
     
     This variant of `recover` ensures that no error is thrown from the handler and allows specifying a catch policy.
     
     - Parameter on: The queue to which the provided closure dispatches.
     - Parameter body: The handler to execute if this promise is rejected.
     - SeeAlso: [Cancellation](http://promisekit.org/docs/)
     */
    func recover(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, _ body: @escaping(Error) throws -> Void) -> CancellablePromise<Void> {
        let cancelBody = { (error: Error) throws -> Void in
            if let error = self.cancelContext.cancelledError, policy == .allErrorsExceptCancellation {
                throw error
            } else {
                try body(error)
            }
        }
        
        let promise = self.catchable.recover(on: on, policy: policy, cancelBody)
        return CancellablePromise(promise, context: self.cancelContext)
    }
}
