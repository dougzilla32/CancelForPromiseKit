//
//  CancellablePromise.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/22/18.
//

import PromiseKit

public class CancellablePromise<T>: CancellableThenable, CancellableCatchMixin {
    public typealias U = Promise<T>
    
    public typealias M = Promise<T>
    
    public var catchable: Promise<T> {
        return promise
    }
    
    public var thenable: Promise<T> {
        return promise
    }
    
    public let promise: Promise<T>
    
    init(_ promise: Promise<T>) {
        self.promise = promise
        if promise.cancelContext == nil {
            promise.cancelContext = CancelContext()
        }
    }

    /// Initialize a new rejected cancellable promise.
    public convenience init(error: Error) {
        self.init(Promise(error: error))
    }
    
    /// Initialize a new cancellable promise bound to the provided `Thenable`.
    public convenience init<U: Thenable>(_ bridge: U) where U.T == T {
        self.init(Promise(bridge))
    }
    
    /// Initialize a new cancellable promise that can be resolved with the provided `Resolver`.
    public convenience init(resolver body: (Resolver<T>) throws -> Void) {
        self.init(Promise(resolver: body))
    }
    
    /// Initialize a new cancellable promise with a cancellable task that can be resolved with the provided `Resolver`.
    public convenience init(task: CancellableTask, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init(Promise(cancel: CancelContext(), task: task, resolver: body))
    }
    
    /// Initialize a new cancellable promise with a cancellable task and rejected with the provided error.
    public convenience init(task: CancellableTask, error: Error) {
        self.init(Promise(cancel: CancelContext(), task: task, error: error))
    }

    /// - Returns: a tuple of a new cancellable pending promise and its `Resolver`.
    public class func pending() -> (promise: CancellablePromise<T>, resolver: Resolver<T>) {
        let rp = Promise<T>.pendingCC()
        return (promise: CancellablePromise(rp.promise), resolver: rp.resolver)
    }
    
    /// - Returns: a new fulfilled cancellable promise.
    public class func value(_ value: T) -> CancellablePromise<T> {
        return CancellablePromise(Promise.valueCC(value))
    }

    /// Internal function required for `Thenable` conformance.
    public func pipe(to: @escaping (Result<T>) -> Void) {
        promise.pipe(to: to)
    }
    
    /// - Returns: The current `Result` for this cancellable promise.
    public var result: Result<T>? {
        return promise.result
    }

    /**
     Immutably and asynchronously inspect the current `Result`:
     
        promise.tap{ print($0) }.then{ /*…*/ }
     */
    public func tap(_ body: @escaping(Result<T>) -> Void) -> CancellablePromise {
        _ = promise.tap(body)
        return self
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
    /// Initializes a new promise fulfilled with `Void`
    public convenience init() {
        self.init(Promise())
    }
}
#endif

public extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue.

         DispatchQueue.global().async(.promise) {
             try md5(input)
         }.done { md5 in
             //…
         }

     - Parameter cancel: The cancel context to use for this promise.
     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Promise` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *)
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], execute body: @escaping () throws -> T) -> CancellablePromise<T> {
        return CancellablePromise(asyncCC(.promise, group: group, qos: qos, flags: flags, execute: body))
    }
}
