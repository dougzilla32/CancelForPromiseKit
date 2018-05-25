//
//  Promise.swift
//  CancelForPromiseKit
//
//  Created by Doug on 4/28/18.
//

import PromiseKit

extension Promise {
    convenience init(cancel: CancelContext, task: CancellableTask? = nil, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)!
        self.init { seal in
            reject = seal.reject
            try body(seal)
        }
        self.cancelContext = cancel
        cancel.append(task: task, reject: reject, description: PromiseDescription(self))
    }

    convenience init(cancel: CancelContext, task: CancellableTask? = nil, error: Error) {
        var reject: ((Error) -> Void)!
        self.init { seal in
            reject = seal.reject
            seal.reject(error)
        }
        self.cancelContext = cancel
        cancel.append(task: task, reject: reject, description: PromiseDescription(self))
    }

    class func pendingCC(cancel: CancelContext? = nil) -> (promise: Promise<T>, resolver: Resolver<T>) {
        let rv = pending()
        let context = cancel ?? CancelContext()
        rv.promise.cancelContext = context
        context.append(task: nil, reject: rv.resolver.reject)
        return rv
    }
    
    /**
     The 'valueCC' extension is provided so that 'value' promises can be cancelled.  This is
     useful for situations where a promise chain is invoked quickly in succession with
     two different values, and a guaranteed is desired that no code will be executed on
     the prior chain after it is cancelled at any point in the chain.

     When invoking 'done' with the standard 'Promise.value' result, the 'cancel' is
     not guaranteed.  This happens because there is a call to 'async' in 'Thenable.done'
     after the check for 'fullfilled' has already happened.  This causes a chain like
     the following:
     
        My app code: Promise.value -> done
        Thenable.done:
          if fulfilled(), async { body }
        My app code: cancel:
          reject (ignored because 'fulfilled()' has already been checked)
        Thenable.done:
          execute body (despited being 'rejected')
     */
    static func valueCC(_ value: T, cancel: CancelContext? = nil) -> Promise<T> {
        var reject: ((Error) -> Void)!

        let promise = Promise<T> { seal in
            reject = seal.reject
            seal.fulfill(value)
        }

        let cancelContext = cancel ?? CancelContext()
        cancelContext.append(task: nil, reject: reject, description: PromiseDescription(promise))
        promise.cancelContext = cancelContext
        return promise
    }
}

#if swift(>=3.1)
extension Promise where T == Void {
    /// Initializes a new promise fulfilled with `Void`
    convenience init(cancel: CancelContext, task: CancellableTask? = nil) {
        self.init()
        self.cancelContext = cancel
        cancel.append(task: nil, reject: nil, description: PromiseDescription(self))
    }
}
#endif

extension DispatchQueue {
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
    final func asyncCC<T>(_: PMKNamespacer, group: DispatchGroup? = nil, qos: DispatchQoS = .default, flags: DispatchWorkItemFlags = [], cancel: CancelContext? = nil, execute body: @escaping () throws -> T) -> Promise<T> {
        let rp = Promise<T>.pending()
        async(group: group, qos: qos, flags: flags) {
            if let error = rp.promise.cancelContext?.cancelledError {
                rp.resolver.reject(error)
            } else {
                do {
                    rp.resolver.fulfill(try body())
                } catch {
                    rp.resolver.reject(error)
                }
            }
        }
        rp.promise.cancelContext = cancel ?? CancelContext()
        return rp.promise
    }
}
