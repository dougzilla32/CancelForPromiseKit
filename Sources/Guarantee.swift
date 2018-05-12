//
//  Guarantee.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import PromiseKit

public extension Guarantee {
    public convenience init(cancel: CancelContext, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(resolver: body)
        self.cancelContext = cancel
    }
    
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: (@escaping(T) -> Void) -> Void) {
        self.init(cancel: cancel, resolver: body)
        cancel.replaceLast(task: task)
    }
    
    public var cancelContext: CancelContext? {
        get {
            return objc_getAssociatedObject(self, &CancelContextKey.cancelContext) as? CancelContext
        }
        set(newValue) {
            objc_setAssociatedObject(self, &CancelContextKey.cancelContext, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func cancel() {
        cancelContext?.cancel()
    }

    @discardableResult
    func doneCC(on: DispatchQueue? = conf.Q.return, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Void) -> Promise<Void> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = """
            Guarantee.doneCC: cancel context is missing in cancel chain at \(fileBasename) \(function):\(line). Specifiy a cancel context in 'doneCC' if the calling guarantee does not have one, for example:
                guaranteeWithoutContext.doneCC(cancel: context) {
                    // body
                }
            
            """
            assert(false, message, file: file, line: line)
            print("*** ERROR *** \(message)")
        }

        let rp: (Promise<Void>, Resolver<Void>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { (value: Result<T>) in
            on.async {
                if let error = cancelContext.cancelledError {
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
                cancelContext.done()
            }
        }
        return rp.0
    }
    
    func mapCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> U) -> Promise<U> {
        if cancel == nil && self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = """
            Guarantee.mapCC: cancel context is missing in cancel chain at \(fileBasename) \(function):\(line). Specifiy a cancel context in 'mapCC' if the calling guarantee does not have one, for example:
                guaranteeWithoutContext.mapCC(cancel: context) { value in
                    // body
                }
            
            """
            assert(false, message, file: file, line: line)
            print("*** ERROR *** \(message)")
        }

        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { (value: Result<T>) in
            on.async {
                if let error = cancelContext.cancelledError {
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
    
    @discardableResult
    func thenCC<U>(on: DispatchQueue? = conf.Q.map, cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(T) -> Guarantee<U>) -> Guarantee<U> /* Promise<U> */ {
        if self.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = """
            Guarantee.thenCC: cancel context is missing in cancel chain at \(fileBasename) \(function):\(line). Specifiy a cancel context in 'thenCC' if the calling guarantee does not have one, for example:
                guaranteeWithoutContext.thenCC(cancel: context) { value in
                    // body
                }
            
            """
            assert(false, message, file: file, line: line)
            print("*** ERROR *** \(message)")
        }

        // Dangit, box is inaccessible so we just call vanilla 'then'
        let promise = then(on: on, body)
        promise.cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        // Use 'true || true' to supress 'code is never executed' compiler warning
        if true || true { return promise }

        let rp: (Promise<U>, Resolver<U>) = Promise.pending()
        let cancelContext = cancel ?? self.cancelContext ?? CancelContext()
        rp.0.cancelContext = cancelContext
        pipe { (value: Result<T>) in
            switch value {
            case .fulfilled(let value):
                on.async {
                    if let error = cancelContext.cancelledError {
                        rp.1.reject(error)
                    } else {
                        let rv = body(value)
                        if let context = rv.cancelContext {
                            cancelContext.append(context: context)
                        }
                        rv.pipe { (value: Result<U>) -> Void in
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
            case .rejected(let error):
                rp.1.reject(error)
            }
        }
        // return rp.0
        return promise
    }
}

