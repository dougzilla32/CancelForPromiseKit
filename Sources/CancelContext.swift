//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

import Foundation

public class CancelContext {
    public enum Cancellable {
        case taskAndReject(CancellableTask?, ((Error) -> Void)?)
        case cancelContext(CancelContext?)
    }
    
    public struct CancelItem {
        public internal(set) var cancellable: Cancellable
        public internal(set) var cancelAttempted = false
        
        mutating func cancel(_ cancelledError: PromiseCancelledError) {
            switch self.cancellable {
            case .taskAndReject(let task, let reject):
                task?.cancel()
                reject?(cancelledError)
                self.cancellable = Cancellable.taskAndReject(task, nil)
            case .cancelContext(let context):
                context?.cancel()
                self.cancellable = Cancellable.cancelContext(nil)
            }
            self.cancelAttempted = true
        }
        
        mutating func done() {
            switch self.cancellable {
            case .taskAndReject:
                self.cancellable = Cancellable.taskAndReject(nil, nil)
            case .cancelContext:
                self.cancellable = Cancellable.cancelContext(nil)
            }
        }
        
        var isCancelled: Bool {
            get {
                switch self.cancellable {
                case .taskAndReject(let task, _):
                    if !(task?.isCancelled ?? false) {
                        return false
                    }
                case .cancelContext(let context):
                    if !(context?.isCancelled ?? false) {
                        return false
                    }
                }
                return true
            }
        }
    }
    
    public private(set) var cancelItems = [CancelItem]()
    
    public private(set) var cancelAttempted = false
    
    public private(set) var cancelledError: PromiseCancelledError? = nil

    public init() { }
    
    public func append(task: CancellableTask? = nil, reject: ((Error) -> Void)? = nil) {
        var item = CancelItem(cancellable: Cancellable.taskAndReject(task, reject), cancelAttempted: false)
        if let error = cancelledError {
            item.cancel(error)
        }
        cancelItems.append(item)
    }
    
    public func append(context: CancelContext) {
        var item = CancelItem(cancellable: Cancellable.cancelContext(context), cancelAttempted: false)
        if let error = cancelledError {
            item.cancel(error)
        }
        cancelItems.append(item)
    }
    
    public func replaceLast(task: CancellableTask? = nil, reject: ((Error) -> Void)? = nil) {
        assert(cancelItems.count != 0, "The context is empty")
        switch cancelItems[cancelItems.count - 1].cancellable {
        case .taskAndReject(let lastTask, let lastReject):
            cancelItems[cancelItems.count - 1].cancellable = Cancellable.taskAndReject(task ?? lastTask, reject ?? lastReject)
        case .cancelContext:
            assert(false, "The last item is not a task")
            break
        }
    }

    public func cancel(file: String = #file, function: String = #function, line: UInt = #line) {
        cancelAttempted = true
        cancelledError = PromiseCancelledError(file: file, function: function, line: line)
        for var info in cancelItems {
            info.cancel(cancelledError!)
        }
    }
    
    public func done(file: String = #file, function: String = #function, line: UInt = #line) {
        for var info in cancelItems {
            info.done()
        }
    }

    public var isCancelled: Bool {
        for info in cancelItems where !info.isCancelled {
            return false
        }
        return true
    }
}
