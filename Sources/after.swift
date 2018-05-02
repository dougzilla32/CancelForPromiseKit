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

public func cancellableAfter(seconds: TimeInterval, cancelContext: CancelContext? = nil) -> Promise<Void> {
    return cancellableAt(when: DispatchTime.now() + seconds, cancelContext: cancelContext)
}

public func cancellableAfter(_ interval: DispatchTimeInterval, cancelContext: CancelContext? = nil) -> Promise<Void> {
    return cancellableAt(when: DispatchTime.now() + interval, cancelContext: cancelContext)
}

public func cancellableAt(when: DispatchTime, cancelContext: CancelContext? = nil) -> Promise<Void> {
    let task = DispatchWorkItemTask()
    var reject: ((Error) -> Void)?

    let promise = Promise<Void> { seal in
        reject = seal.reject
        print("SEAL ME atWithCancel")
        task.task = DispatchWorkItem {
            seal.fulfill(())
        }
        DispatchQueue.global(qos: .default).asyncAfter(deadline: when, execute: task.task!)
    }
    
    cancelContext?.add(cancel: promise.cancel)
    promise.cancellableTask = task
    promise.cancelReject = reject
    return promise
}

