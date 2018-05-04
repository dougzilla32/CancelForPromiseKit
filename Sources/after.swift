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

public func after(seconds: TimeInterval, cancel: CancelType) -> Promise<Void> {
    return cancellableAt(when: DispatchTime.now() + seconds, cancel: cancel)
}

public func cancellableAfter(_ interval: DispatchTimeInterval, cancel: CancelType) -> Promise<Void> {
    return cancellableAt(when: DispatchTime.now() + interval, cancel: cancel)
}

public func cancellableAt(when: DispatchTime, cancel: CancelType) -> Promise<Void> {
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
    
    if case .context(let context) = cancel {
        context.add(cancel: promise.cancel)
    }
    promise.cancellableTask = task
    promise.cancelReject = reject
    return promise
}

