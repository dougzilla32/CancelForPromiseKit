//
//  Catchable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import Dispatch
import PromiseKit

public extension CatchMixin {
    @discardableResult
    func catchCC(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, _ body: @escaping(Error) -> Void) -> CPKFinalizer {
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        let finalizer = CPKFinalizer(cancel: cancelContext)
        pipe {
            if let cancelError = cancelContext.cancelledError {
                if policy == .allErrors || !cancelError.isCancelled {
                    body(cancelError)
                    finalizer.pending.resolve(())
                }
            } else {
                switch $0 {
                case .rejected(let error):
                    guard policy == .allErrors || !error.isCancelled else {
                        fallthrough
                    }
                    on.async {
                        if let cancelError = cancelContext.cancelledError {
                            body(cancelError)
                            finalizer.pending.resolve(())
                        } else {
                            body(error)
                            finalizer.pending.resolve(())
                        }
                    }
                case .fulfilled:
                    finalizer.pending.resolve(())
                }
            }
        }
        return finalizer
    }
}

public class CPKFinalizer {
    let pending = Guarantee<Void>.pending()
    let cancel: CancelContext
    
    init(cancel: CancelContext) {
        self.cancel = cancel
    }
    
    /// `finally` is the same as `ensure`, but it is not chainable
    public func finally(_ body: @escaping () -> Void) {
        pending.guarantee.done(body)
        cancel.done()
    }
}

public extension CatchMixin {
    func recoverCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, _ body: @escaping(Error) throws -> U) -> Promise<T> where U.T == T {

        // Dangit, box is inaccessible so we just call vanilla 'then'
        let promise = self.recover(on: on, policy: policy, body)
        promise.cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        // Use 'true || true' to supress 'code is never executed' compiler warning
        if true || true { return promise }
        
        let rp: (Promise<U.T>, Resolver<U.T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            if let cancelError = cancelContext.cancelledError {
                rp.1.reject(cancelError)
            } else {
                switch $0 {
                case .fulfilled(let value):
                    rp.1.fulfill(value)
                case .rejected(let error):
                    if policy == .allErrors || !error.isCancelled {
                        on.async {
                            if let cancelError = cancelContext.cancelledError {
                                rp.1.reject(cancelError)
                            } else {
                                do {
                                    let rv = try body(error)
                                    guard rv !== rp.0 else { throw PMKError.returnedSelf }
                                    if let context = rv.cancelContext {
                                        cancelContext.append(context: context)
                                    }
                                    rv.pipe { (value: Result<U.T>) -> Void in
                                        if let error = cancelContext.cancelledError {
                                            rp.1.reject(error)
                                        } else {
                                            // Dangit, box is inaccessible otherwise this works great
                                            // rp.1.box.seal(value)
                                        }
                                    }
                                } catch {
                                    rp.1.reject(error)
                                }
                            }
                        }
                    } else {
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }
    
    @discardableResult
    func recoverCC(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, _ body: @escaping(Error) -> Guarantee<T>) -> Guarantee<T> {
        // Dangit, box is inaccessible so we just call vanilla 'then'
        let guarantee = self.recover(on: on, body)
        guarantee.cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        // Use 'true || true' to supress 'code is never executed' compiler warning
        if true || true { return guarantee }
        
        let rp: (Promise<T>, Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { (value: Result<T>) in
            if let cancelError = cancelContext.cancelledError {
                rp.1.reject(cancelError)
            } else {
                switch value {
                case .fulfilled(let value):
                    rp.1.fulfill(value)
                case .rejected(let error):
                    on.async {
                        if let cancelError = cancelContext.cancelledError {
                            rp.1.reject(cancelError)
                        } else {
                            let rv = body(error)
                            if let context = rv.cancelContext {
                                cancelContext.append(context: context)
                            }
                            rv.pipe { (value: Result<T>) -> Void in
                                if let error = cancelContext.cancelledError {
                                    rp.1.reject(error)
                                } else {
                                    switch value {
                                    case .fulfilled(let value):
                                        // Dangit, box is inaccessible otherwise this works great
                                        // rp.1.box.seal(value)
                                        let _ = value
                                    case .rejected(let error):
                                        rp.1.reject(error)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // return rp.0
        return guarantee
    }
    
    func ensureCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, _ body: @escaping () -> Void) -> Promise<T> {
        let rp: (Promise<T>, Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { result in
            on.async {
                if let error = cancelContext.cancelledError {
                    rp.1.reject(error)
                } else {
                    body()
                    switch (result) {
                    case .fulfilled(let value):
                        rp.1.fulfill(value)
                    case .rejected(let error):
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }
    
    func ensureThenCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, _ body: @escaping () -> Guarantee<Void>) -> Promise<T> {
        let rp: (Promise<T>, Resolver<T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { result in
            on.async {
                if let error = cancelContext.cancelledError {
                    rp.1.reject(error)
                } else {
                    let rv = body()
                    if let context = rv.cancelContext {
                        cancelContext.append(context: context)
                    }
                    rv.done {
                        switch (result) {
                        case .fulfilled(let value):
                            rp.1.fulfill(value)
                        case .rejected(let error):
                            rp.1.reject(error)
                        }
                    }
                }
            }
        }
        return rp.0
    }
    
    func cauterizeCC(cancel: CancelContext? = nil) {
        self.catchCC(cancel: cancel) {
            Swift.print("PromiseKit:cauterized-error:", $0)
        }
    }
}

public extension CatchMixin where T == Void {
    @discardableResult
    func recoverCC(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, _ body: @escaping(Error) -> Void) -> Guarantee<Void> {
        let rg: (Guarantee<Void>, (()) -> Void) = Guarantee.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rg.0.cancelContext = cancelContext
        pipe {
            if let cancelError = cancelContext.cancelledError {
                body(cancelError)
                rg.1(())
            } else {
                switch $0 {
                case .fulfilled:
                    rg.1(())
                case .rejected(let error):
                    on.async {
                        if let cancelError = cancelContext.cancelledError {
                            body(cancelError)
                            rg.1(())
                       } else {
                            body(error)
                            rg.1(())
                        }
                    }
                }
            }
        }
        return rg.0
    }
    
    func recoverCC(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, cancel: CancelContext? = nil, _ body: @escaping(Error) throws -> Void) -> Promise<Void> {
        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            if let cancelError = cancelContext.cancelledError {
                do {
                    rp.1.fulfill(try body(cancelError))
                } catch {
                    rp.1.reject(error)
                }
            } else {
                switch $0 {
                case .fulfilled:
                    rp.1.fulfill(())
                case .rejected(let error):
                    if policy == .allErrors || !error.isCancelled {
                        on.async {
                            if let cancelError = cancelContext.cancelledError {
                                do {
                                    rp.1.fulfill(try body(cancelError))
                                } catch {
                                    rp.1.reject(error)
                                }
                            } else {
                                do {
                                    rp.1.fulfill(try body(error))
                                } catch {
                                    rp.1.reject(error)
                                }
                            }
                        }
                    } else {
                        rp.1.reject(error)
                    }
                }
            }
        }
        return rp.0
    }
}
