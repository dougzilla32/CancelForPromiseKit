//
//  Catchable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import Dispatch
import PromiseKit

public extension CatchMixin {
    @discardableResult
    func catchCC(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Void) -> CPKFinalizer {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "catchCC", file: file, function: function, line: line)
        }
        
        return CPKFinalizer(self.catch(on: on, policy: policy, body), cancel: cancelContext)
    }
}

public class CPKFinalizer {
    let pmkFinalizer: PMKFinalizer
    let cancelContext: CancelContext
    
    init(_ pmkFinalizer: PMKFinalizer, cancel: CancelContext? = nil) {
        self.pmkFinalizer = pmkFinalizer
        self.cancelContext = cancel ?? CancelContext()
    }
    
    /// `finallyCC` is the same as `ensureCC`, but it is not chainable
    @discardableResult
    public func finallyCC(_ body: @escaping () -> Void) -> CancelContext {
        pmkFinalizer.finally(body)
        return cancelContext
    }
    
    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelContext.cancel(error: error, file: file, function: function, line: line)
    }
}

public extension CatchMixin {
    func recoverCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> U) -> Promise<T> where U.T == T {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> U in
            if let cancelledError = cancelContext.cancelledError {
                if policy == .allErrorsExceptCancellation {
                    throw cancelledError
                } else {
                    cancelContext.recover()
                }
            }
            let rv = try body(error)
            if let context = rv.cancelContext {
                cancelContext.append(context: context)
            }
            return rv
        }
        
        let promise = self.recover(on: on, policy: policy, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func ensureCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Void) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "ensureCC", file: file, function: function, line: line)
        }
        
        let rp: (promise: Promise<T>, resolver: Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.promise.cancelContext = cancelContext
        pipe { result in
            on.async {
                body()
                switch result {
                case .fulfilled(let value):
                    if let error = cancelContext.cancelledError {
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
    
    func ensureThenCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Guarantee<Void>) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "ensureThenCC", file: file, function: function, line: line)
        }
        
        let rp: (promise: Promise<T>, resolver: Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.promise.cancelContext = cancelContext
        pipe { result in
            on.async {
                let rv = body()
                if let context = rv.cancelContext {
                    cancelContext.append(context: context)
                }
                rv.done {
                    switch result {
                    case .fulfilled(let value):
                        if let error = cancelContext.cancelledError {
                            rp.resolver.reject(error)
                        } else {
                            rp.resolver.fulfill(value)
                        }
                    case .rejected(let error):
                        rp.resolver.reject(error)
                    }
                }
            }
        }
        return rp.promise
    }
    
    func cauterizeCC(cancel: CancelContext? = nil) {
        self.catchCC(cancel: cancel) {
            Swift.print("PromiseKit:cauterized-error:", $0)
        }
    }
}

public extension CatchMixin where T == Void {
    func recoverCC(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> Void in
            if let error = cancelContext.cancelledError, policy == .allErrorsExceptCancellation {
                throw error
            } else {
                try body(error)
            }
        }
        
        let promise = self.recover(on: on, policy: policy, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
}
