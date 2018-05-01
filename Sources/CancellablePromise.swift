//
//  CancellablePromise.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import Foundation
import PromiseKit

// MARK: Cancellable Tasks

// TODO: change these to weak references (keys and values), does it work for ObjectIdentifier?
// private var cancellableTaskMap: NSMapTable<ObjectIdentifierClass, CancelItem> = NSMapTable.strongToWeakObjects()
var cancellableTaskMap = [ObjectIdentifier: CancellableTask]()

class CancellableTask {
    var reject: ((Error) -> Void)?
    
    func cancel() {
        cancelAttempted = true
        reject?(PromiseCancelledError())
    }
    
    var isCancelled: Bool {
        get {
            return cancelAttempted
        }
    }
    
    var cancelAttempted = false
}

//class ObjectIdentifierClass: Hashable {
//    let id: ObjectIdentifier
//
//    init(_ id: ObjectIdentifier) {
//        self.id = id
//
//    }
//
//    var hashValue: Int {
//        get { return id.hashValue }
//
//    }
//
//    static func == (lhs: ObjectIdentifierClass, rhs: ObjectIdentifierClass) -> Bool {
//        return lhs.id == rhs.id
//    }
//}

class DispatchWorkItemTask: CancellableTask {
    var task: DispatchWorkItem?
    
    override init() {
        super.init()
    }
    
    init(_ task: DispatchWorkItem) {
        super.init()
        self.task = task
    }
    
    override public func cancel() {
        super.cancel()
        
        // Invoke the work item now, causing it to error out with a cancellation error
        task?.perform()
        
        // Cancel the work item so that it doesn't get invoked later.  'perform' must be called before 'cancel', otherwise the perform will get ignored.
        task?.cancel()
    }
    
    override public var isCancelled: Bool {
        get {
            return task?.isCancelled ?? false
        }
    }
}

// MARK: Cancel Context

public class CancelContext {
    private var cancelFunctions = [() -> Void]()
    
    func add(cancel: @escaping () -> Void) {
        cancelFunctions.append(cancel)
    }
    
    public func cancelAll() {
        for cancel in cancelFunctions {
            cancel()
        }
    }
}

// MARK: Promise extensions

extension Promise {
    public class func valueWithCancel(_ value: T, cancelContext: CancelContext? = nil) -> Promise<T> {
        let task = DispatchWorkItemTask()
        
        let promise = Promise<T> { seal in
            task.reject = seal.reject
            Swift.print("SEAL ME valueWithCancel")
            //            task.task = DispatchWorkItem() {
            seal.fulfill(value)
            //            }
            //            Swift.print("SET WORK ITEM HOLDER \(task)")
            //            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now() + 0.001, execute: task.task!)
        }
        
        cancelContext?.add(cancel: promise.cancel)
        cancellableTaskMap[ObjectIdentifier(promise)] = task
        return promise
    }
    
    convenience init(task: CancellableTask, cancelContext: CancelContext? = nil, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init() { seal in
            task.reject = seal.reject
            Swift.print("SEAL ME CancellableTask")
            do {
                try body(seal)
            } catch {
                seal.reject(error)
            }
        }
        
        cancelContext?.add(cancel: self.cancel)
        //        cancellableTaskMap.setObject(
        //            CancelDispatchWorkItem(workItem: task),
        //            forKey: ObjectIdentifierClass(ObjectIdentifier(self)))
        cancellableTaskMap[ObjectIdentifier(self)] = task
    }
    
    func cancel() {
        Swift.print("try cancel")
        //        if let cancelItem = cancellableTaskMap.object(forKey: ObjectIdentifierClass(ObjectIdentifier(self))) {
        if let cancelItem = cancellableTaskMap[ObjectIdentifier(self)] {
            cancelItem.cancel()
        }
    }
    
    var isCancelled: Bool {
        get {
            //            if let cancelItem = cancellableTaskMap.object(forKey: ObjectIdentifierClass(ObjectIdentifier(self))) {
            if let cancelItem = cancellableTaskMap[ObjectIdentifier(self)] {
                return cancelItem.isCancelled
            } else {
                return false
            }
        }
    }
    
    var isCancellable: Bool {
        get {
            //            return cancellableTaskMap.object(forKey: ObjectIdentifierClass(ObjectIdentifier(self))) != nil
            return cancellableTaskMap[ObjectIdentifier(self)] != nil
        }
    }
    
    var cancelAttempted: Bool {
        get {
            if let cancelItem = cancellableTaskMap[ObjectIdentifier(self)] , cancelItem.cancelAttempted {
                return true
            } else {
                return false
            }
        }
    }
    
    func cancelledError() -> PromiseCancelledError? {
        //        if let cancelItem = cancellableTaskMap.object(forKey: ObjectIdentifierClass(ObjectIdentifier(self))) {
        if let cancelItem = cancellableTaskMap[ObjectIdentifier(self)] , cancelItem.cancelAttempted {
            Swift.print("cancelledError.cancelAttemped \(cancelItem.cancelAttempted)")
            return PromiseCancelledError()
        } else {
            Swift.print("cancelledError.cancelAttemped nil or false")
            return nil
        }
    }
}
