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

public extension Guarantee {
    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, cancel: CancelContext, _ body: @escaping(T) -> Void) -> Promise<Void> {
        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        pipe { (value: T) in
            on.async {
                if let error = cancel.cancelledError {
                    rp.1.reject(error)
                } else {
                    body(value)
                    rp.1.fulfill(())
                }
            }
        }
        return rp.0
    }

    func map<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ body: @escaping(T) -> U) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        pipe { (value: T) in
            on.async {
                if let error = cancel.cancelledError {
                    rp.1.reject(error)
                } else {
                    rp.1.fulfill(body(value))
                }
            }
        }
        return rp.0
    }
    
    /*
    @discardableResult
    func then<U>(on: DispatchQueue? = conf.Q.map, _ body: @escaping(T) -> Guarantee<U>) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        pipe { (value: T) in
            on.async {
                // Dangit, box is inaccessible
                body(value).pipe(to: rp.1.box.seal)
            }
        }
        return rp.0
    }
    */
}

public extension Thenable {
    /*
    func then<U: Thenable>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, file: StaticString = #file, line: UInt = #line, _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        let rp: (Promise<U.T>, Resolver<U.T>) = Promise.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancel.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            let rv = try body(value)
                            guard rv !== rp.1 else { throw PMKError.returnedSelf }
                            
                            // Dangit, box is inaccessible
                            rv.pipe(to: rp.1.box.seal)
                        } catch {
                            rp.1.reject(error)
                        }
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        return rp.0
    }
    */
    
    func map<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ transform: @escaping(T) throws -> U) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancel.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            rp.1.fulfill(try transform(value))
                        } catch {
                            rp.1.reject(error)
                        }
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        return rp.0
    }
    
    func compactMap<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ transform: @escaping(T) throws -> U?) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancel.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            if let rv = try transform(value) {
                                rp.1.fulfill(rv)
                            } else {
                                throw PMKError.compactMap(value, U.self)
                            }
                        } catch {
                            rp.1.reject(error)
                        }
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        return rp.0
    }
    
    func done(on: DispatchQueue? = conf.Q.return, cancel: CancelContext, _ body: @escaping(T) throws -> Void) -> Promise<Void> {
        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancel.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            try body(value)
                            rp.1.fulfill(())
                        } catch {
                            rp.1.reject(error)
                        }
                    }
                }
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        return rp.0
    }
    
    func get(on: DispatchQueue? = conf.Q.return, cancel: CancelContext, _ body: @escaping (T) throws -> Void) -> Promise<T> {
        return map(on: on, cancel: cancel) {
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
