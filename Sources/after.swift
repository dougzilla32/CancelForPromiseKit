//
//  after.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import Foundation
import PromiseKit

// MARK: Cancellable 'after'

public func afterWithCancel(seconds: TimeInterval, cancelContext: CancelContext? = nil) -> Promise<Void> {
    return atWithCancel(when: DispatchTime.now() + seconds, cancelContext: cancelContext)
}

public func afterWithCancel(_ interval: DispatchTimeInterval, cancelContext: CancelContext? = nil) -> Promise<Void> {
    return atWithCancel(when: DispatchTime.now() + interval, cancelContext: cancelContext)
}

public func atWithCancel(when: DispatchTime, cancelContext: CancelContext? = nil) -> Promise<Void> {
    let task = DispatchWorkItemTask()
    let promise = Promise<Void> { seal in
        task.reject = seal.reject
        print("SEAL ME atWithCancel")
        task.task = DispatchWorkItem {
            seal.fulfill(())
        }
        DispatchQueue.global(qos: .default).asyncAfter(deadline: when, execute: task.task!)
    }
    
    cancelContext?.add(cancel: promise.cancel)
    cancellableTaskMap[ObjectIdentifier(promise)] = task
    return promise
}

