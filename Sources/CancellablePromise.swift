//
//  CancellablePromise.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 4/28/18.
//

import class Foundation.Thread
import Dispatch
@_exported import PromiseKit

/**
 A `CancellablePromise` is a functional abstraction around a failable and cancellable asynchronous operation.
 
 At runtime the promise can become a member of a chain of promises, where the `cancelContext` is used to track and cancel (if desired) all promises in this chain.
 
 - See: `CancellableThenable`
 */
public class CancellablePromise<T>: CancellableThenable, CancellableCatchMixin {
    /// Delegate `promise` for this CancellablePromise
    public let promise: Promise<T>
    
    /// Type of the delegate `thenable`
    public typealias U = Promise<T>
    
    /// Delegate `thenable` for this CancellablePromise
    public var thenable: U {
        return promise
    }

    /// Type of the delegate `catchable`
    public typealias M = Promise<T>
    
    /// Delegate `catchable` for this CancellablePromise
    public var catchable: M {
        return promise
    }
    
    /// The CancelContext associated with this CancellablePromise
    public var cancelContext: CancelContext
    
    /// Tracks the cancel items for this CancellablePromise.  These items are removed from the associated CancelContext when the promise resolves.
    public var cancelItemList: CancelItemList
    
    init(_ promise: Promise<T>, context: CancelContext? = nil, cancelItemList: CancelItemList? = nil) {
        self.promise = promise
        self.cancelContext = context ?? CancelContext()
        self.cancelItemList = cancelItemList ?? CancelItemList()
    }
    
    /// Initialize a new rejected cancellable promise.
    public convenience init(task: CancellableTask? = nil, error: Error) {
        var reject: ((Error) -> Void)!
        self.init(Promise { seal in
            reject = seal.reject
            seal.reject(error)
        })
        self.appendCancellableTask(task: task, reject: reject)
    }
    
    /// Initialize a new cancellable promise bound to the provided `Thenable`.
    public convenience init<U: Thenable>(task: CancellableTask? = nil, _ bridge: U) where U.T == T {
        var reject: ((Error) -> Void)!
        self.init(Promise { seal in
            reject = seal.reject
            bridge.done(on: nil) {
                seal.fulfill($0)
            }.catch {
                seal.reject($0)
            }
        })
        self.appendCancellableTask(task: task, reject: reject)
    }
    
    /// Initialize a new cancellable promise that can be resolved with the provided `Resolver`.
    public convenience init(task: CancellableTask? = nil, resolver body: (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)!
        self.init(Promise { seal in
            reject = seal.reject
            try body(seal)
        })
        self.appendCancellableTask(task: task, reject: reject)
    }
    
    /// Initialize a new cancellable promise using the giving Promise and it's Resolver.
    public convenience init(task: CancellableTask? = nil, promise: Promise<T>, resolver: Resolver<T>) {
        self.init(promise)
        self.appendCancellableTask(task: task, reject: resolver.reject)
    }

    /// - Returns: a tuple of a new cancellable pending promise and its `Resolver`.
    public class func pending() -> (promise: CancellablePromise<T>, resolver: Resolver<T>) {
        let rp = Promise<T>.pending()
        return (promise: CancellablePromise(rp.promise), resolver: rp.resolver)
    }
    
    /// - Returns: a new fulfilled cancellable promise.
    public class func valueCC(_ value: T) -> CancellablePromise<T> {
        var reject: ((Error) -> Void)!
        
        let promise = Promise<T> { seal in
            reject = seal.reject
            seal.fulfill(value)
        }
        
        let cp = CancellablePromise(promise)
        cp.appendCancellableTask(task: nil, reject: reject)
        return cp
    }

    /// Internal function required for `Thenable` conformance.
    /// - See: `Thenable.pipe`
    public func pipe(to: @escaping (PromiseKit.Result<T>) -> Void) {
        promise.pipe(to: to)
    }
    
    /// - Returns: The current `Result` for this cancellable promise.
    /// - See: `Thenable.result`
    public var result: PromiseKit.Result<T>? {
        return promise.result
    }

    /**
     Blocks this thread, so—you know—don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    public func wait() throws -> T {
        return try promise.wait()
    }
}

#if swift(>=3.1)
extension CancellablePromise where T == Void {
    /// Initializes a new cancellable promise fulfilled with `Void`
    public convenience init() {
        self.init(Promise())
    }

    /// Initializes a new cancellable promise fulfilled with `Void` and with the given `CancellableTask`
    public convenience init(task: CancellableTask) {
        self.init()
        self.appendCancellableTask(task: task, reject: nil)
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
     
     - Parameter cancelValue: No-op -- workaround for compiler problem, can get 'ambiguous use of asynCC' error otherwise
     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Promise` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *)
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], cancelValue: T? = nil, execute body: @escaping () throws -> T) -> CancellablePromise<T> {
        let rp = CancellablePromise<T>.pending()
        async(group: group, qos: qos, flags: flags) {
            if let error = rp.promise.cancelContext.cancelledError {
                rp.resolver.reject(error)
            } else {
                do {
                    rp.resolver.fulfill(try body())
                } catch {
                    rp.resolver.reject(error)
                }
            }
        }
        return rp.promise
    }
}
