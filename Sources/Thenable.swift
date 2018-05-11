//
//  Thenable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/11/18.
//

import PromiseKit

struct CancelContextKey {
    static var cancelContext: UInt8 = 0
}

public extension Thenable {
    public var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &CancelContextKey.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &CancelContextKey.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func thenCC<U: Thenable>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> U) -> Promise<U.T> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = "Promise.thenCC: cancel chain broken at \(fileBasename) \(function):\(line)"
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
        }

        // Dangit, box is inaccessible so we just call vanilla 'then'
        let promise = self.then(on: on, file: file, line: line, body)
        promise.cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        // Use 'true || true' to supress 'code is never executed' compiler warning
        if true || true { return promise }

        let rp: (Promise<U.T>, Resolver<U.T>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancelContext.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            let rv = try body(value)
                            guard rv !== rp.0 else { throw PMKError.returnedSelf }
                            if let context = rv.cancelContext {
                                cancelContext.append(context: context)
                            }
                            
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
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = "Promise.mapCC: cancel chain broken at \(fileBasename) \(function):\(line)"
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
        }

        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancelContext.cancelledError {
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
    
    func compactMapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping(T) throws -> U?) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = "Promise.compactMapCC: cancel chain broken at \(fileBasename) \(function):\(line)"
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
        }

        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancelContext.cancelledError {
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
    
    func doneCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) throws -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = "Promise.doneCC: cancel chain broken at \(fileBasename) \(function):\(line)"
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
        }

        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe {
            switch $0 {
            case .fulfilled(let value):
                on.async {
                    if let error = cancelContext.cancelledError {
                        rp.1.reject(error)
                    } else {
                        do {
                            try body(value)
                            rp.1.fulfill(())
                        } catch {
                            rp.1.reject(error)
                        }
                    }
                    cancelContext.done()
                }
            case .rejected(let error):
                rp.1.reject(error)
                cancelContext.done()
            }
        }
        return rp.0
    }
    
    func getCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (T) throws -> Void) -> Promise<T> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = "Promise.getCC: cancel chain broken at \(file) \(function):\(line)"
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
        }

        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        return mapCC(on: on, cancel: cancelContext) {
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

