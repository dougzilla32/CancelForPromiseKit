//
//  Guarantee.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import PromiseKit

public extension Guarantee {
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(resolver: body)
        self.cancelContext = cancel
        cancel.append(task: task, reject: nil)
    }
    
    public var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &CancelContextKey.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &CancelContextKey.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func cancel() {
        cancelContext?.cancel()
    }

    @discardableResult
    func doneCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Guarantee", functionName: "doneCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (value: T) throws -> Void in
            defer {
                cancelContext.done()
            }
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                body(value)
            }
        }
        
        let promise = self.done(on: on, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> U) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Guarantee", functionName: "mapCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (value: T) throws -> U in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                return body(value)
            }
        }
        
        let promise = self.map(on: on, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    @discardableResult
    func thenCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Guarantee<U>) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Guarantee", functionName: "thenCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (value: T) throws -> Guarantee<U> in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                let rv = body(value)
                if let context = rv.cancelContext {
                    cancelContext.append(context: context)
                }
                return rv
            }
        }
        
        let promise = self.then(on: on, file: file, line: line, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
}

