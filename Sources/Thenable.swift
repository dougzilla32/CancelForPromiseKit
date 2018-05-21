//
//  Thenable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/11/18.
//

import PromiseKit

public struct CancelContextKey {
    public static var cancelContext: UInt8 = 0
}

public extension Thenable {
    public var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &CancelContextKey.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &CancelContextKey.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelContext?.cancel(error: error, file: file, function: function, line: line)
    }

    func thenCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "thenCC", file: file, function: function, line: line)
       }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (value: T) throws -> U in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                let rv = try body(value)
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
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "mapCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelTransform = { (value: T) throws -> U in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                return try transform(value)
            }
        }
        
        let promise = self.map(on: on, cancelTransform)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func compactMapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U?) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "compactMapCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelTransform = { (value: T) throws -> U? in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                return try transform(value)
            }
        }
        
        let promise = self.compactMap(on: on, cancelTransform)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func doneCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "doneCC", file: file, function: function, line: line)
        }
        
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let cancelBody = { (value: T) throws -> Void in
            if let error = cancelContext.cancelledError {
                throw error
            } else {
                try body(value)
            }
        }
        
        let promise = self.done(on: on, cancelBody)
        promise.cancelContext = cancelContext
        return promise
    }
    
    func getCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (T) throws -> Void) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            ErrorConditions.cancelContextMissing(className: "Promise", functionName: "getCC", file: file, function: function, line: line)
        }

        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        return mapCC(on: on, cancel: cancelContext) {
            try body($0)
            return $0
        }
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
