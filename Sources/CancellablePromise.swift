//
//  CancellablePromise.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import PromiseKit

public extension Promise {
    public class func value(_ value: T, cancel: CancelMode) -> Promise<T> {
        if case .disabled = cancel {
            return Promise.value(value)
        }
        
        let task = DispatchWorkItemTask()
        var reject: ((Error) -> Void)?
        
        let promise = Promise<T> { seal in
            reject = seal.reject
            Swift.print("SEAL ME valueWithCancel")
//            task.task = DispatchWorkItem() {
            seal.fulfill(value)
//            }
//            Swift.print("SET WORK ITEM HOLDER \(task)")
//            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now() + 0.001, execute: task.task!)
        }
        
        if case .context(let context) = cancel {
            context.add(cancel: promise.cancel)
        }
        promise.cancellableTask = task
        promise.cancelReject = reject
        return promise
    }
 
    public convenience init(cancel: CancelMode, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)?
        if case .disabled = cancel {
            self.init(resolver: body)
            return
        }
        
        self.init() { seal in
            reject = seal.reject
            Swift.print("SEAL ME CancellableTask")
            do {
                try body(seal)
            } catch {
                seal.reject(error)
            }
        }
        
        if case .context(let context) = cancel {
            context.add(cancel: self.cancel)
        }
        self.cancelReject = reject
    }
    
    public convenience init(cancel: CancelMode, task: CancellableTask, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init(cancel: cancel, resolver: body)
        self.cancellableTask = task
    }
    
    public func cancel(file: String = #file, _ function: String = #function, line: Int = #line) {
        Swift.print("try cancel")
        cancelAttempted = true
        cancelReject?(PromiseCancelledError(file: file, function: function, line: line))
        cancellableTask?.cancel()
   }
    
    public var isCancelled: Bool {
        get {
            if let cancelItem = cancellableTask {
                return cancelItem.isCancelled
            } else {
                return false
            }
        }
    }
    
    public var isCancellable: Bool {
        get {
            return cancellableTask != nil
        }
    }

    public var cancellableTask: CancellableTask? {
        get {
            return objc_getAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancellableTask) as? CancellableTask
        }
        set {
            objc_setAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancellableTask, newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public var cancelAttempted: Bool {
        get {
            return (objc_getAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancelAttempted) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancelAttempted, newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var cancelReject: ((Error) -> Void)? {
        get {
            return objc_getAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancelReject) as? (Error) -> Void
        }
        set {
            objc_setAssociatedObject(self, &CancellablePromiseAssociatedKeys.cancelReject, newValue,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

struct CancellablePromiseAssociatedKeys {
    static var cancellableTask: UInt8 = 0
    static var cancelAttempted: UInt8 = 0
    static var cancelReject: UInt8 = 0
}
