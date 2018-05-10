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
     * useful for situations where a promise chain is invoked quickly in succession with
     * two different values, and a guaranteed is needed that no code will be executed on
     * the prior chains after they are cancelled.
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
     *
     * // TODO: To avoid this problem entirely, use Thenable.doneC(cancel:) rather than Promise.value(cancel:).
     * // Promise.value(cancel:) is still provided because Thenable.then(cancel:) cannot currently be
     * // implemented.
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
        promise.cancelContext = cancel
        return promise
    }
 
    public convenience init(cancel: CancelContext, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)?
        self.init() { seal in
            reject = seal.reject
            try body(seal)
        }
        cancel.append(reject: reject)
        self.cancelContext = cancel
    }
    
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init(cancel: cancel, resolver: body)
        cancel.replaceLast(task: task)
    }
}

private struct AssociatedKeys {
    static var cancelContext: UInt8 = 0
}


public extension Guarantee {
    public convenience init(cancel: CancelContext, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(resolver: body)
        self.cancelContext = cancel
    }
    
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(cancel: cancel, resolver: body)
        cancel.replaceLast(task: task)
    }
    
    public private(set) var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func doneCC(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Void) -> Promise<Void> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Guarantee.doneCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return done(on: on, cancel: context, body)
        } else {
            return done(on: on, body)
        }
    }
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> U) -> Promise<U> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Guarantee.mapCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return map(on: on, cancel: context, body)
        } else {
            return map(on: on, body)
        }
    }
    
    // Marked as private because 'Resolver.box.seal' is inaccessible so this doesn't work
    func thenCC<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Guarantee<U>) -> Guarantee<U> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Guarantee.thenCC: cancel chain broken at \(file).\(function):\(line)")
        }
        let promise = then(on: on, body)
        promise.cancelContext = self.cancelContext
        return promise
        
        /* Cannot use this code because 'Resolver.box.seal' is inaccessible so it doesn't work
        if let context = self.cancelContext {
            return then(on: on, cancel: context, body)
        } else {
            return then(on: on, body)
        }
        */
    }
    
    @discardableResult
    func done(on: DispatchQueue? = conf.Q.return, cancel: CancelContext, _ body: @escaping(T) -> Void) -> Promise<Void> {
        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        rp.0.cancelContext = cancel
        pipe { (value: Result<T>) in
            on.async {
                if let error = cancel.cancelledError {
                    rp.1.reject(error)
                } else {
                    switch value {
                    case .fulfilled(let value):
                        body(value)
                        rp.1.fulfill(())
                    case .rejected(let error):
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }

    func map<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ body: @escaping(T) -> U) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        rp.0.cancelContext = cancel
        pipe { (value: Result<T>) in
            on.async {
                if let error = cancel.cancelledError {
                    rp.1.reject(error)
                } else {
                    switch value {
                    case .fulfilled(let value):
                        rp.1.fulfill(body(value))
                    case .rejected(let error):
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }
    
    // Marked as private because 'Resolver.box.seal' is inaccessible so this doesn't work
    @discardableResult
    private func then<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ body: @escaping(T) -> Guarantee<U>) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        rp.0.cancelContext = cancel
        pipe { (value: Result<T>) in
            on.async {
                // Dangit, box is inaccessible otherwise this works great
                // body(value).pipe(to: rp.1.box.seal)
            }
        }
        return rp.0
    }
}

public extension Thenable {
    public internal(set) var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    
    // Marked as private because 'Resolver.box.seal' is inaccessible so this doesn't work
    func thenCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Promise.thenCC: cancel chain broken at \(file).\(function):\(line)")
        }
        let promise = then(on: on, file: file, line: line, body)
        promise.cancelContext = self.cancelContext
        return promise
        
        /*
         if let context = self.cancelContext {
            return then(on: on, cancel: context, file: file, line: line, body)
         } else {
            return then(on: on, file: file, line: line, body)
         }
         */
    }
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U) -> Promise<U> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Promise.mapCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return map(on: on, cancel: context, transform)
        } else {
            return map(on: on, transform)
        }
    }
    
    func compactMapCC<U>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U?) -> Promise<U> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Promise.compactMapCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return compactMap(on: on, cancel: context, transform)
        } else {
            return compactMap(on: on, transform)
        }
    }
    
    func doneCC(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> Void) -> Promise<Void> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Promise.doneCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return done(on: on, cancel: context, body)
        } else {
            return done(on: on, body)
        }
    }
    
    func getCC(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (T) throws -> Void) -> Promise<T> {
        if self.cancelContext == nil {
            let file = URL(fileURLWithPath: "\(file)").deletingPathExtension().lastPathComponent
            NSLog("WARNING Promise.getCC: cancel chain broken at \(file).\(function):\(line)")
        }
        if let context = self.cancelContext {
            return get(on: on, cancel: context, body)
        } else {
            return get(on: on, body)
        }
    }

    // Marked as private because 'Resolver.box.seal' is inaccessible so this doesn't work
    private func then<U: Thenable>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, file: StaticString = #file, line: UInt = #line, _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        let rp: (Promise<U.T>, Resolver<U.T>) = Promise.pending()
        rp.0.cancelContext = cancel
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancel.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            let rv = try body(value)
                            if rv.cancelContext == nil {
                                rv.cancelContext = cancel
                            }
                            guard rv !== rp.1 else { throw PMKError.returnedSelf }
                            
                            // Dangit, box is inaccessible otherwise this works great
                            // rv.pipe(to: rp.1.box.seal)
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
    
    func map<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext, _ transform: @escaping(T) throws -> U) -> Promise<U> {
        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        rp.0.cancelContext = cancel
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
        rp.0.cancelContext = cancel
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
        rp.0.cancelContext = cancel
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
