//
//  CancellableGuarantee.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/22/18.
//

import PromiseKit

/// A `CancellableGuarantee` is a functional abstraction around an asynchronous operation that cannot error but can be cancelled.
/// When a guarantee is cancelled any associated tasks are cancelled and the chain is aborted.
public class CancellableGuarantee<T>: CancellableThenable {
    public typealias U = Guarantee<T>
    
    public var thenable: Guarantee<T> {
        return guarantee
    }
    
    public var guarantee: Guarantee<T>
    
    init(_ guarantee: Guarantee<T>) {
        self.guarantee = guarantee
        if guarantee.cancelContext == nil {
            guarantee.cancelContext = CancelContext()
        }
    }
    
    /// Initialize a new cancellable guarantee that can be resolved with the provided `Resolver`.
    public convenience init(resolver body: ((T) -> Void) -> Void) {
        self.init(Guarantee(resolver: body))
    }
    
    /// - Returns: a tuple of a new cancellable pending guarantee and its `Resolver`.
    public class func pending() -> (guarantee: CancellableGuarantee<T>, resolver: Resolver<T>) {
        let rg = Guarantee<T>.pendingCC()
        return (guarantee: CancellableGuarantee(rg.guarantee), resolver: rg.resolver)
    }
    
    /// - Returns: a new fulfilled cancellable guarantee.
    public class func value(_ value: T) -> CancellableGuarantee<T> {
        return CancellableGuarantee(Guarantee.value(value))
    }
    
    /// Internal function required for `Thenable` conformance.
    public func pipe(to: @escaping (Result<T>) -> Void) {
        guarantee.pipe(to: to)
    }
    
    /// - Returns: The current `Result` for this cancellable guarantee.
    public var result: Result<T>? {
        return guarantee.result
    }
    
    /**
     Blocks this thread, so—you know—don’t call this on a serial thread that
     any part of your chain may use. Like the main thread for example.
     */
    public func wait() throws -> T {
        return guarantee.wait()
    }

    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Void) -> CancellablePromise<Void> {
        return CancellablePromise(guarantee.doneCC(on: on, file: file, function: function, line: line, body))
    }

    func map<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> U) -> CancellablePromise<U> {
        return CancellablePromise(guarantee.mapCC(on: on, file: file, function: function, line: line, body))
    }
    
    @discardableResult
    func then<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Guarantee<U>) -> CancellablePromise<U> {
        return CancellablePromise(guarantee.thenCC(on: on, file: file, function: function, line: line, body))
    }
}

#if swift(>=3.1)
extension CancellableGuarantee where T == Void {
    public convenience init() {
        self.init(Guarantee())
    }
}
#endif

extension DispatchQueue {
    /**
     Asynchronously executes the provided closure on a dispatch queue.

         DispatchQueue.global().asyncCC(.promise) {
             md5(input)
         }.doneCC { md5 in
             //…
         }

     - Parameter cancel: The cancel context to use for this promise.
     - Parameter body: The closure that resolves this promise.
     - Returns: A new `Guarantee` resolved by the result of the provided closure.
     */
    @available(macOS 10.10, iOS 2.0, tvOS 10.0, watchOS 2.0, *)
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], execute body: @escaping () -> T) -> CancellablePromise<T> {
        return CancellablePromise(asyncCC(.promise, group: group, qos: qos, flags: flags, execute: body))
    }
}
