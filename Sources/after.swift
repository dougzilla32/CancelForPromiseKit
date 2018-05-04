//
//  after.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import Foundation
import PromiseKit

public func after(seconds: TimeInterval, cancel: CancelMode) -> Promise<Void> {
    return at(when: DispatchTime.now() + seconds, cancel: cancel)
}

public func after(_ interval: DispatchTimeInterval, cancel: CancelMode) -> Promise<Void> {
    return at(when: DispatchTime.now() + interval, cancel: cancel)
}

public func at(when: DispatchTime, cancel: CancelMode) -> Promise<Void> {
    if case .disabled = cancel {
        return Promise<Void> { seal in
            let task = DispatchWorkItem {
#if swift(>=4.0)
                seal.fulfill(())
#else
                seal.fulfill()
#endif
            }
            q.asyncAfter(deadline: when, execute: task)
        }
    }
    
    let task = DispatchWorkItemTask()
    var reject: ((Error) -> Void)?

    let promise = Promise<Void> { seal in
        reject = seal.reject
        print("SEAL ME atWithCancel")
        task.task = DispatchWorkItem {
#if swift(>=4.0)
            seal.fulfill(())
#else
            seal.fulfill()
#endif
        }
        q.asyncAfter(deadline: when, execute: task.task!)
    }
    
    if case .context(let context) = cancel {
        context.add(cancel: promise.cancel)
    }
    promise.cancellableTask = task
    promise.cancelReject = reject
    return promise
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
