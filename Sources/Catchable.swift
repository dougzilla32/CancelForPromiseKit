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
    func catchCC(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Void) -> PMKFinalizer {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "catchCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) -> Void in
            body(error)
            cancelContext.done()
        }
        
        return self.catch(on: on, policy: policy, cancelBody)
    }
}

public extension CatchMixin {
    func recoverCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> U) -> Promise<T> where U.T == T {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> U in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                let rv = try body(error)
                if let context = rv.cancelContext {
                    cancelContext.append(context: context)
                }
                return rv
            }
        }
        
        let promise = self.recover(on: on, policy: policy, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    @discardableResult
    func recoverCC(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Guarantee<T>) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> Guarantee<T> in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                let rv = body(error)
                if let context = rv.cancelContext {
                    cancelContext.append(context: context)
                }
                return rv
            }
        }
        
        let promise = self.recover(on: on, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func ensureCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Void) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "ensureCC", file: file, function: function, line: line)
        }
        
        let rp: (Promise<T>, Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { result in
            on.async {
                if let error = cancelContext.cancelledError {
                    rp.1.reject(error)
                } else {
                    body()
                    switch (result) {
                    case .fulfilled(let value):
                        rp.1.fulfill(value)
                    case .rejected(let error):
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }
    
    func ensureThenCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Guarantee<Void>) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "ensureThenCC", file: file, function: function, line: line)
        }
        
        let rp: (Promise<T>, Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { result in
            on.async {
                if let error = cancelContext.cancelledError {
                    rp.1.reject(error)
                } else {
                    let rv = body()
                    if let context = rv.cancelContext {
                        cancelContext.append(context: context)
                    }
                    rv.done {
                        switch (result) {
                        case .fulfilled(let value):
                            rp.1.fulfill(value)
                        case .rejected(let error):
                            rp.1.reject(error)
                        }
                    }
                }
            }
        }
        return rp.0
    }
    
    func cauterizeCC(cancel: CancelContext? = nil) {
        self.catchCC(cancel: cancel) {
            Swift.print("PromiseKit:cauterized-error:", $0)
        }
    }
}

public extension CatchMixin where T == Void {
    @discardableResult
    func recoverCC(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> Void in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                body(error)
            }
        }
        
        let promise = self.recover(on: on, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func recoverCC(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "recoverCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (error: Error) throws -> Void in
            if let error = cancelContext.cancelledError {
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
