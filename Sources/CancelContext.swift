//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

import PromiseKit

class CancelItem: Hashable, CustomDebugStringConvertible {
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
    
    public var debugDescription: String {
        return rawPointerDescription(obj: self)
    }
    
    func cancel(error: Error) {
        task?.cancel()
        reject?(error)
        reject = nil
        cancelAttempted = true
    }
    
    var isCancelled: Bool {
        return task?.isCancelled ?? cancelAttempted
    }
}

public class CancelContext: CustomDebugStringConvertible {
    private var cancelItemList = [CancelItem]()
    private var cancelItemSet = Set<CancelItem>()

    public init() { }
    
    public var debugDescription: String {
        return rawPointerDescription(obj: self)
    }

    public var cancelAttempted: Bool {
        return cancelledError != nil
    }
    
    public private(set) var cancelledError: Error?
    
    public func append(task: CancellableTask?, reject: ((Error) -> Void)?) {
        let item = CancelItem(task: task, reject: reject)
        if let error = cancelledError {
            item.cancel(error: error)
        }
        cancelItemList.append(item)
        cancelItemSet.insert(item)
    }
    
    func append(context childContext: CancelContext) {
        guard childContext !== self else {
            return
        }
        
        if let parentError = cancelledError {
            if !childContext.cancelAttempted {
                childContext.cancel(error: parentError)
            }
        } else if let childError = childContext.cancelledError {
            if !cancelAttempted {
                cancel(error: childError)
            }
        }
        
        for childItem in childContext.cancelItemList {
            if !cancelItemSet.contains(childItem) {
                cancelItemList.append(childItem)
                cancelItemSet.insert(childItem)
            }
        }
    }
    
    public func cancel(error: Error? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        cancelledError = error ?? PromiseCancelledError(file: file, function: function, line: line)
        for item in cancelItemList {
            item.cancel(error: cancelledError!)
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
        cancelledError = nil
    }
}
