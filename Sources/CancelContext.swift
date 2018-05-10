//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

public class CancelContext {
    public struct CancelItem {
        public internal(set) var task: CancellableTask?
        public internal(set) var reject: ((Error) -> Void)?
        public internal(set) var cancelAttempted = false
    }
    
    public private(set) var cancelItems = [CancelItem]()
    
    public private(set) var cancelAttempted = false
    
    public private(set) var cancelledError: PromiseCancelledError? = nil

    public init() { }
    
    public func append(task: CancellableTask? = nil, reject: ((Error) -> Void)? = nil) {
        cancelItems.append(CancelItem(task: task, reject: reject, cancelAttempted: false))
    }
    
    public func replaceLast(task: CancellableTask? = nil, reject: ((Error) -> Void)? = nil) {
        assert(cancelItems.count != 0)
        if task != nil {
            cancelItems[cancelItems.count - 1].task = task
        }
        if reject != nil {
            cancelItems[cancelItems.count - 1].reject = reject
        }
    }

    public func cancel(file: String = #file, function: String = #function, line: UInt = #line) {
        cancelAttempted = true
        cancelledError = PromiseCancelledError(file: file, function: function, line: line)
        for var info in cancelItems {
            info.task?.cancel()
            info.reject?(cancelledError!)
            info.reject = nil
            info.cancelAttempted = true
        }
    }

    public var isCancelled: Bool {
        for info in cancelItems {
            if !(info.task?.isCancelled ?? false) {
                return false
            }
        }
        return true
    }
}
