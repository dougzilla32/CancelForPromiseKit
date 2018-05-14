//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

import PromiseKit

class CancelItem: Hashable {
    lazy var hashValue: Int = {
        return ObjectIdentifier(self).hashValue
    }()
    
    static func == (lhs: CancelItem, rhs: CancelItem) -> Bool {
        return lhs === rhs
    }
    
    let task: CancellableTask?
    var reject: ((Error) -> Void)?
    var cancelAttempted = false
    
    init(task: CancellableTask?, reject: ((Error) -> Void)?) {
        self.task = task
        self.reject = reject
    }
    
    func cancel(error: Error) {
        task?.cancel()
        reject?(error)
        reject = nil
        cancelAttempted = true
    }
    
    var isCancelled: Bool {
        get {
            return task?.isCancelled ?? cancelAttempted
        }
    }
}

public class CancelContext {
    private var cancelItemList = [CancelItem]()
    private var cancelItemSet = Set<CancelItem>()
    
    public init() { }
    
    public var cancelAttempted: Bool {
        get {
            return cancelledError != nil
        }
    }
    
    public private(set) var cancelledError: Error? = nil
    
    public func append(task: CancellableTask?, reject: ((Error) -> Void)?) {
        let item = CancelItem(task: task, reject: reject)
        if let error = cancelledError {
            item.cancel(error: error)
        }
        cancelItemList.append(item)
        cancelItemSet.insert(item)
    }
    
    public func append(context: CancelContext) {
        guard context !== self else {
            return
        }

        if let parentError = cancelledError {
            if !context.cancelAttempted {
                context.cancel(error: parentError)
            }
        } else if let childError = context.cancelledError {
            if !cancelAttempted {
                cancel(error: childError)
            }
        }
        
        for childItem in context.cancelItemList {
            if !cancelItemSet.contains(childItem) {
                cancelItemList.append(childItem)
                cancelItemSet.insert(childItem)
            }
        }
    }
    
    public func cancel(error: Error? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        let cancelledError = error ?? PromiseCancelledError(file: file, function: function, line: line)
        for item in cancelItemList {
            item.cancel(error: cancelledError)
        }
    }

    public var isCancelled: Bool {
        for item in cancelItemList where !item.isCancelled {
            return false
        }
        return true
    }

    public func done(file: String = #file, function: String = #function, line: UInt = #line) {
        cancelItemList.removeAll()
        cancelItemSet.removeAll()
    }
}
