//
//  CancellableTask.swift
//  CancellablePromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

import Foundation

public protocol CancellableTask {
    func cancel()
    
    var isCancelled: Bool { get }
}

open class DispatchWorkItemTask: CancellableTask {
    var task: DispatchWorkItem?
    
    init() { }
    
    init(_ task: DispatchWorkItem) {
        self.task = task
    }
    
    public func cancel() {
        // Invoke the work item now, causing it to error out with a cancellation error
        task?.perform()
        
        // Cancel the work item so that it doesn't get invoked later.  'perform' must be called before 'cancel', otherwise the perform will get ignored.
        task?.cancel()
    }
    
    public var isCancelled: Bool {
        get {
            return task?.isCancelled ?? false
        }
    }
}
