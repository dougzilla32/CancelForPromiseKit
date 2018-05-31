//
//  CancellableGuarantee.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/10/18.
//

import PromiseKit

/// A `CancellableGuarantee` is a functional abstraction around an asynchronous operation that cannot error but can be cancelled.
/// When a guarantee is cancelled any associated tasks are cancelled but the chain completes successfully.  In this situation the
/// guarantee would successfully resolve with a value that indicates cancellation -- perhaps an error, 'nil', an empty
/// string, or a zero length array.
public class CancellableGuarantee<T>: CancellableThenable {
    public typealias U = Guarantee<T>
    
    public var thenable: U {
        return guarantee
    }
    
    public var guarantee: Guarantee<T>
    
    public let cancelValue: T?
    
    init(_ guarantee: Guarantee<T>, cancelValue: T? = nil, context: CancelContext? = nil) {
        self.guarantee = guarantee
        self.cancelValue = cancelValue
        self.cancelContext = context ?? CancelContext()
    }
    
    /// Initialize a new cancellable guarantee that can be resolved with the provided `Resolver`.
    public convenience init(cancelValue: T? = nil, resolver body: ((T) -> Void) -> Void) {
        self.init(Guarantee(resolver: body), cancelValue: cancelValue)
    }
    
    /// Initialize a new cancellable guarantee with a cancellable task that can be resolved with the provided `Resolver`.
    public convenience init(task: CancellableTask, cancelValue: T? = nil, resolver body: ((T) -> Void) -> Void) {
        self.init(Guarantee(resolver: body), cancelValue: cancelValue)
        self.appendCancellableTask(task: task, reject: nil)
    }
    
    /// - Returns: a tuple of a new cancellable pending guarantee and its `Resolver`.
    public class func pending(cancelValue: T? = nil) -> (guarantee: CancellableGuarantee<T>, resolve: (T) -> Void) {
        let rg = Guarantee<T>.pending()
        return (guarantee: CancellableGuarantee(rg.guarantee, cancelValue: cancelValue), resolve: rg.resolve)
    }
    
    /// - Returns: a new fulfilled cancellable guarantee.
    public class func value(_ value: T, cancelValue: T? = nil) -> CancellableGuarantee<T> {
        return CancellableGuarantee(Guarantee.value(value), cancelValue: cancelValue)
    }
    
    /// Internal function required for `Thenable` conformance.
    public func pipe(to: @escaping (Result<T>) -> Void) {
        guarantee.pipe(to: to)
    }
    
    /// - Returns: The current `Result` for this cancellable guarantee.
    public var result: Result<T>? {
        return guarantee.result
    }
}

public extension CancellableGuarantee {
    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, cancelValue: T? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Void) -> CancellableGuarantee<Void> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Guarantee", functionName: #function, file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (value: T) -> Void in
            let value = self.cancelContext?.cancelledError == nil ? value : (self.cancelValue ?? value)
            self.cancelContext?.removeItems(self.cancelItems, clearList: true)
            body(value)
        }
        
        let guarantee: Guarantee<Void> = self.guarantee.done(on: on, cancelBody)
        return CancellableGuarantee<Void>(guarantee, context: self.cancelContext)
    }

    func map<U>(on: DispatchQueue? = conf.Q.map, cancelValue: U? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> U) -> CancellableGuarantee<U> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Guarantee", functionName: #function, file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (value: T) -> U in
            let value = self.cancelContext?.cancelledError == nil ? value : (self.cancelValue ?? value)
            self.cancelContext?.removeItems(self.cancelItems, clearList: true)
            return body(value)
        }
        
        let guarantee = self.guarantee.map(on: on, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }
    
    @discardableResult
    func then<U>(on: DispatchQueue? = conf.Q.map, cancelValue: U? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> CancellableGuarantee<U>) -> CancellableGuarantee<U> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Guarantee", functionName: #function, file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (value: T) -> Guarantee<U> in
            let value = self.cancelContext?.cancelledError == nil ? value : (self.cancelValue ?? value)
            let rv = body(value)
            if rv.cancelContext == nil {
                ErrorConditions.cancelContextMissingFromBody(className: "Guarantee", functionName: #function, file: file, function: function, line: line)
            }
            self.appendCancelContext(from: rv)
            return rv.guarantee
        }
        
        let guarantee = self.guarantee.then(on: on, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }

    @discardableResult
    func then<U>(on: DispatchQueue? = conf.Q.map, cancelValue: U? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Guarantee<U>) -> CancellableGuarantee<U> {
        if self.cancelContext == nil {
            ErrorConditions.cancelContextMissingInChain(className: "Guarantee", functionName: #function, file: file, function: function, line: line)
            self.cancelContext = CancelContext()
        }
        
        let cancelBody = { (value: T) -> Guarantee<U> in
            let value = self.cancelContext?.cancelledError == nil ? value : (self.cancelValue ?? value)
            return body(value)
        }
        
        let guarantee = self.guarantee.then(on: on, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }

    public func asVoid() -> CancellableGuarantee<Void> {
        return map(on: nil) { _ in }
    }
    
    /**
     Blocks this thread, so—you know—don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    public func wait() throws -> T {
        return guarantee.wait()
    }
}

#if swift(>=3.1)
extension CancellableGuarantee where T == Void {
    public convenience init(context: CancelContext? = nil) {
        self.init(Guarantee(), cancelValue: (), context: context)
    }

    public convenience init(_ guarantee: Guarantee<T>, context: CancelContext? = nil) {
        self.init(guarantee, cancelValue: (), context: context)
    }

    public convenience init(task: CancellableTask) {
        self.init()
        self.appendCancellableTask(task: task, reject: nil)
    }

    class func createVoid(_ guarantee: Guarantee<T>, context: CancelContext? = nil) -> CancellableGuarantee<T> {
        return CancellableGuarantee(guarantee, context: context)
    }
}
#endif

extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue.

         DispatchQueue.global().asyncCC(.promise) {
             md5(input)
         }.done { md5 in
             //…
         }

     - Parameter cancel: The cancel context to use for this promise.
     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Guarantee` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], cancelValue: T, execute body: @escaping () -> T) -> CancellableGuarantee<T> {
        let rg = CancellableGuarantee<T>.pending(cancelValue: cancelValue)
        async(group: group, qos: qos, flags: flags) {
            rg.resolve(body())
        }
        return rg.guarantee
    }
}
