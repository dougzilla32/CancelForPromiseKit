//
//  CancellablePromise.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//

import PromiseKit

public extension Promise {
    /**
     * This extension is provided so that 'value' promises can be cancelled.  This is
     * useful for situations where a promise chain involving values is quickly and repeatedly
     * being executed, and a guaranteed is needed that no code will be executed on that chain
     * after it is cancelled.
     *
     * When invoking 'done' with the standard 'Promise.value' result, the 'cancel' is
     * not guaranteed.  This happens because there is a call to 'async' in 'Thenable.done'
     * after the check for 'fullfilled' has already happened.  This causes a chain like
     * the following:
     *
     *   My app code: Promise.value -> done
     *   Thenable.done:
     *     if fulfilled(), async { body }
     *   My app code: cancel:
     *     reject (ignored because 'fulfilled()' has already been checked)
     *   Thenable.done:
     *     execute body (despited being 'rejected')
     *
     * The workaround (below) is to run an 'asyncAfter' with a deadline very slightly in the
     * future.  This gives the 'cancel' a change to happen before 'done' checks 'fulfilled'.
     * Not a great workaround because there is still a window where you call 'cancel' and later
     * the body is still invoked.
     */
    public class func value(_ value: T, cancel: CancelContext) -> Promise<T> {
        var task: DispatchWorkItem!
        var reject: ((Error) -> Void)?

        let promise = Promise<T> { seal in
            reject = seal.reject
            task = DispatchWorkItem() {
                seal.fulfill(value)
            }
            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now() + 0.01, execute: task)
        }

        cancel.append(task: task, reject: reject)
        return promise
    }
 
    public convenience init(cancel: CancelContext, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)?
        self.init() { seal in
            reject = seal.reject
            try body(seal)
        }
        cancel.append(reject: reject)
    }
    
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init(cancel: cancel, resolver: body)
        cancel.replaceLast(task: task)
    }
}
