//
//  CancellableTask.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

import Dispatch

/**
 Use this protocol to define cancellable tasks for CancellablePromise.
 */
public protocol CancellableTask {
    /// Cancel the associated task
    func cancel()
    
    /// `true` if the task was successfully cancelled, `false` otherwise
    var isCancelled: Bool { get }
}

/// Extend DispatchWorkItem to be a CancellableTask
extension DispatchWorkItem: CancellableTask { }
