//
//  Catchable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import Dispatch
import PromiseKit

extension CatchMixin {
    @discardableResult
    func catchCC(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Void) -> CPKFinalizer {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "catchCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        return CPKFinalizer(self.catch(on: on, policy: policy, body), cancel: self.cancelContext!)
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
    func finally(_ body: @escaping () -> Void) -> CancelContext {
        pmkFinalizer.finally(body)
        return cancelContext
    }
    
    /// `finallyCC` is the same as `ensureCC`, but it is not chainable
    @discardableResult
    func finallyCC(_ body: @escaping () -> Void) -> CancelContext {
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

extension CatchMixin {
    func recoverCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> U) -> Promise<T> where U.T == T {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (error: Error) throws -> U in
            if let cancelledError = self.cancelContext?.cancelledError {
                if policy == .allErrorsExceptCancellation {
                    throw cancelledError
                } else {
                    self.cancelContext?.recover()
                }
            }
            let rv = try body(error)
            if let context = rv.cancelContext {
                self.cancelContext?.append(context: context)
            } else {
                ErrorConditions.cancelContextMissingFromBody(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
            }
            return rv
        }
        
        let promise = self.recover(on: on, policy: policy, cancelBody)
        promise.cancelContext = self.cancelContext
        return promise
    }
    
    func ensureCC(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Void) -> Promise<T> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "ensureCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let rp: (promise: Promise<T>, resolver: Resolver<T>) = Promise.pending()
        rp.promise.cancelContext = self.cancelContext
        pipe { result in
            on.async {
                body()
                switch result {
                case .fulfilled(let value):
                    if let error = self.cancelContext?.cancelledError {
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
    
    func ensureThenCC(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Promise<Void>) -> Promise<T> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "ensureThenCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let rp: (promise: Promise<T>, resolver: Resolver<T>) = Promise.pending()
        rp.promise.cancelContext = cancelContext
        pipe { result in
            on.async {
                let rv = body()
                if let context = rv.cancelContext {
                    self.cancelContext?.append(context: context)
                } else {
                    ErrorConditions.cancelContextMissingFromBody(className: "Promise", functionName: "ensureThenCC", file: file, function: function, line: line)
                }
                rv.doneCC {
                    switch result {
                    case .fulfilled(let value):
                        if let error = self.cancelContext?.cancelledError {
                            rp.resolver.reject(error)
                        } else {
                            rp.resolver.fulfill(value)
                        }
                    case .rejected(let error):
                        rp.resolver.reject(error)
                    }
                }.catchCC {
                    rp.resolver.reject($0)
                }
            }
        }
        return rp.promise
    }
    
    func cauterizeCC(file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "cauterizeCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }

        self.catchCC {
            Swift.print("PromiseKit:cauterized-error:", $0)
        }
    }
}

extension CatchMixin where T == Void {
    func recoverCC(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> Void) -> Promise<Void> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (error: Error) throws -> Void in
            if let error = self.cancelContext?.cancelledError, policy == .allErrorsExceptCancellation {
                throw error
            } else {
                try body(error)
            }
        }
        
        let promise = self.recover(on: on, policy: policy, cancelBody)
        promise.cancelContext = self.cancelContext
        return promise
    }
}
