//
//  CancellableGuarantee.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/10/18.
//

import class Foundation.Thread
import Dispatch
@_exported import PromiseKit

/**
 A `CancellableGuarantee` is a functional abstraction around an asynchronous operation that can be cancelled but cannot error.
 
 When a cancellable guarantee is cancelled any associated tasks are cancelled but the chain completes successfully.  In this situation the guarantee would successfully resolve with whatever value the task returns after being cancelled -- perhaps an error, `nil`, an empty string, or a zero length array.  Alternatively, the `cancelValue` optional parameter explicitly specifies a value to use when the guarantee is cancelled.
 
 - See: `Thenable`
 */
public class CancellableGuarantee<T>: CancellableThenable {
    /// Delegate `guarantee` for this CancellableGuarantee
    public var guarantee: Guarantee<T>
    
    /// Type of the delegate `thenable`
    public typealias U = Guarantee<T>
    
    /// Delegate `thenable` for this CancellableGuarantee
    public var thenable: U {
        return guarantee
    }
    
    /// CancelContext associated with this CancellableGuarantee
    public var cancelContext: CancelContext
    
    /// Tracks the cancel items for this CancellableGuarantee.  These items are removed from the associated CancelContext when the guarantee resolves.
    public var cancelItemList: CancelItemList
    
    /// Override value to use for resolution after the CancellableGuarantee is cancelled.  If `nil` (default) then do not override the resolved value when the CancellableGuarantee is cancelled.
    public let cancelValue: T?
    
    /**
     Initializes a new cancellable guarantee bound to the provided `Guarantee`
     - Parameter guarantee: `Guarantee` to bind
     - Parameter cancelValue: optional override value to use when cancelled
     - Parameter context: optional `CancelContext` to associate with this `CancellableGuarantee`
     */
    init(_ guarantee: Guarantee<T>, cancelValue: T? = nil, context: CancelContext? = nil) {
        self.guarantee = guarantee
        self.cancelValue = cancelValue
        self.cancelContext = context ?? CancelContext()
        self.cancelItemList = CancelItemList()
    }
    
    /**
     Initialize a pending `CancellableGuarantee` that can be resolved with the provided closure’s parameter.
     - Parameter task: cancellable task
     - Parameter cancelValue: optional override value to use when cancelled
     - Parameter resolver: invoked to resolve the `CancellableGuarantee`
     */
    public convenience init(task: CancellableTask? = nil, cancelValue: T? = nil, resolver body: ((T) -> Void) -> Void) {
        self.init(Guarantee(resolver: body), cancelValue: cancelValue)
        self.appendCancellableTask(task: task, reject: nil)
    }
    
    /// - Parameter cancelValue: optional override value to use when cancelled
    /// - Returns: a tuple of a pending `CancellableGuarantee` and a function that resolves it.
    public class func pending(cancelValue: T? = nil) -> (guarantee: CancellableGuarantee<T>, resolve: (T) -> Void) {
        let rg = Guarantee<T>.pending()
        return (guarantee: CancellableGuarantee(rg.guarantee, cancelValue: cancelValue), resolve: rg.resolve)
    }
    
    /// - Parameter cancelValue: optional override value to use when cancelled
    /// - Returns: a `CancellableGuarantee` sealed with the provided value.
    public class func valueCC(_ value: T, cancelValue: T? = nil) -> CancellableGuarantee<T> {
        return CancellableGuarantee(Guarantee.value(value), cancelValue: cancelValue)
    }
    
    /// Internal function required for `Thenable` conformance.
    public func pipe(to: @escaping (PromiseKit.Result<T>) -> Void) {
        guarantee.pipe(to: to)
    }
    
    /// - Returns: The current `Result` for this cancellable guarantee.
    public var result: PromiseKit.Result<T>? {
        return guarantee.result
    }
}

public extension CancellableGuarantee {
    /// - See: `CancellableThenable.done(on:flags:_:)`
    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, flags: DispatchWorkItemFlags? = nil, cancelValue: T? = nil, _ body: @escaping(T) -> Void) -> CancellableGuarantee<Void> {
        let cancelBody = { (value: T) -> Void in
            let value = self.cancelContext.removeItems(self.cancelItemList, clearList: true) == nil
                ? value : (self.cancelValue ?? value)
            body(value)
        }
        
        let guarantee: Guarantee<Void> = self.guarantee.done(on: on, flags: flags, cancelBody)
        return CancellableGuarantee<Void>(guarantee, cancelValue: (), context: self.cancelContext)
    }

    /// - See: `CancellableThenable.get(on:flags:_:)`
    func get(on: DispatchQueue? = conf.Q.return, flags: DispatchWorkItemFlags? = nil, cancelValue: T? = nil, _ body: @escaping (T) -> Void) -> CancellableGuarantee<T> {
        return map(on: on, flags: flags) {
            body($0)
            return $0
        }
    }
    
    /// - See: `CancellableThenable.map(on:flags:_:)`
    func map<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, cancelValue: U? = nil, _ body: @escaping(T) -> U) -> CancellableGuarantee<U> {
        let cancelBody = { (value: T) -> U in
            let value = self.cancelContext.removeItems(self.cancelItemList, clearList: true) == nil
                ? value : (self.cancelValue ?? value)
            
            return body(value)
        }
        
        let guarantee = self.guarantee.map(on: on, flags: flags, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }
    
    /// - See: `CancellableThenable.then(on:flags:_:)`
    @discardableResult
    func then<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, cancelValue: U? = nil, _ body: @escaping(T) -> CancellableGuarantee<U>) -> CancellableGuarantee<U> {
        let cancelBody = { (value: T) -> Guarantee<U> in
            let value = self.cancelContext.cancelledError == nil ? value : (self.cancelValue ?? value)
            let rv = body(value)
            self.appendCancelContext(from: rv)
            return rv.guarantee
        }
        
        let guarantee = self.guarantee.then(on: on, flags: flags, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }

    /// - See: `CancellableThenable.thenCC(on:flags:_:)`
    @discardableResult
    func thenCC<U>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, cancelValue: U? = nil, _ body: @escaping(T) -> Guarantee<U>) -> CancellableGuarantee<U> {
        let cancelBody = { (value: T) -> Guarantee<U> in
            let value = self.cancelContext.cancelledError == nil ? value : (self.cancelValue ?? value)
            return body(value)
        }
        
        let guarantee = self.guarantee.then(on: on, flags: flags, cancelBody)
        return CancellableGuarantee<U>(guarantee, cancelValue: cancelValue, context: self.cancelContext)
    }

    /// - See: `CancellableThenable.asVoid()`
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

public extension CancellableGuarantee where T: Sequence {

    /**
     `CancellableGuarantee<[T]>` => `T` -> `CancellableGuarantee<V>` => `CancellableGuarantee<[V]>`

         let context = firstly {
             .valueCC([1,2,3])
         }.thenMap {
             .value($0 * 2)
         }.done {
             // $0 => [2,4,6]
         }.cancelContext

         //…
     
         context.cancel()
     */
    func thenMap<V>(on: DispatchQueue? = conf.Q.map, flags: DispatchWorkItemFlags? = nil, cancelValue: [V]? = nil, _ transform: @escaping(T.Iterator.Element) -> CancellableGuarantee<V>) -> CancellableGuarantee<[V]> {
        return then(on: on, flags: flags) {
            when(fulfilled: $0.map(transform))
        }.recover { _ in
            return CancellableGuarantee<[V]>.valueCC(cancelValue ?? [])
        }
    }
}

#if swift(>=3.1)
extension CancellableGuarantee where T == Void {
    /// Initializes a new cancellable guarantee fulfilled with `Void`
    /// - Parameter context: optional `CancelContext` to associate with this `CancellableGuarantee`
    public convenience init(context: CancelContext? = nil) {
        self.init(Guarantee(), cancelValue: (), context: context)
    }

    /// Initializes a new cancellable guarantee fulfilled with `Void` bound to the provided `Guarantee`
    /// - Parameter guarantee: `Guarantee` to bind
    /// - Parameter context: optional `CancelContext` to associate with this `CancellableGuarantee`
    public convenience init(_ guarantee: Guarantee<T>, context: CancelContext? = nil) {
        self.init(guarantee, cancelValue: (), context: context)
    }

    /// Initializes a new promise fulfilled with `Void` and with the given `CancellableTask`
    public convenience init(task: CancellableTask) {
        self.init()
        self.appendCancellableTask(task: task, reject: nil)
    }

    class func createVoid(_ guarantee: Guarantee<T>, context: CancelContext? = nil) -> CancellableGuarantee<T> {
        return CancellableGuarantee(guarantee, cancelValue: (), context: context)
    }
}
#endif

public extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue.

         let context = DispatchQueue.global().asyncCC(.promise) {
             try md5(input)
         }.done { md5 in
             //…
         }.cancelContext
     
         //…
     
         context.cancel()

     - Parameter cancelValue: The value to use if the CancellableGuarantee is cancelled.
     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Guarantee` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], cancelValue: T? = nil, execute body: @escaping () -> T) -> CancellableGuarantee<T> {
        let rg = CancellableGuarantee<T>.pending(cancelValue: cancelValue)
        async(group: group, qos: qos, flags: flags) {
            rg.resolve(body())
        }
        return rg.guarantee
    }
}
