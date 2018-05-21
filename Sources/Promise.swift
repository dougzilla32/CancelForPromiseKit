//
//  Promise.swift
//  CancelForPromiseKit
//
//  Created by Doug on 4/28/18.
//

import PromiseKit

public extension Promise {
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
    public class func valueCC(_ value: T, cancel: CancelContext? = nil) -> Promise<T> {
        var task: DispatchWorkItem!
        var reject: ((Error) -> Void)!

        let promise = Promise<T> { seal in
            reject = seal.reject
            task = DispatchWorkItem {
                seal.fulfill(value)
            }
            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now(), execute: task)
        }

        let cancelContext = cancel ?? CancelContext()
        cancelContext.append(task: task, reject: reject, description: PromiseDescription(promise))
        promise.cancelContext = cancelContext
        return promise
    }
 
    public convenience init(cancel: CancelContext, task: CancellableTask? = nil, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)!
        self.init { seal in
            reject = seal.reject
            try body(seal)
        }
        self.cancelContext = cancel
        cancel.append(task: task, reject: reject, description: PromiseDescription(self))
    }

    public convenience init(cancel: CancelContext, task: CancellableTask? = nil, error: Error) {
        var reject: ((Error) -> Void)!
        self.init { seal in
            reject = seal.reject
            seal.reject(error)
        }
        self.cancelContext = cancel
        cancel.append(task: task, reject: reject, description: PromiseDescription(self))
    }

    public convenience init(cancel: CancelContext, task: CancellableTask? = nil) {
        var reject: ((Error) -> Void)!
        self.init { seal in
            reject = seal.reject
        }
        self.cancelContext = cancel
        cancel.append(task: task, reject: reject, description: PromiseDescription(self))
    }
}
