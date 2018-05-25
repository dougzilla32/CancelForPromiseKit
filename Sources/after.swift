//
//  after.swift
//  CancelForPromiseKit
//
//  Created by Doug on 4/28/18.
//

import Foundation
import PromiseKit

public func afterCP(seconds: TimeInterval) -> CancellablePromise<Void> {
    return CancellablePromise(at(time: DispatchTime.now() + seconds))
}

public func afterCP(_ interval: DispatchTimeInterval) -> CancellablePromise<Void> {
    return CancellablePromise(at(time: DispatchTime.now() + interval))
}

func afterCC(seconds: TimeInterval, cancel: CancelContext? = nil) -> Promise<Void> {
    return at(time: DispatchTime.now() + seconds, cancel: cancel)
}

func afterCC(_ interval: DispatchTimeInterval, cancel: CancelContext? = nil) -> Promise<Void> {
    return at(time: DispatchTime.now() + interval, cancel: cancel)
}

func at(time: DispatchTime, cancel: CancelContext? = nil) -> Promise<Void> {
#if swift(>=4.0)
    var fulfill: ((()) -> Void)?
#else
    var fulfill: (() -> Void)?
#endif
    var reject: ((Error) -> Void)?

    let promise = Promise<Void> { seal in
        fulfill = seal.fulfill
        reject = seal.reject
    }
    
    let task = DispatchWorkItem {
#if swift(>=4.0)
        fulfill!(())
#else
        fulfill!()
#endif
    }
    q.asyncAfter(deadline: time, execute: task)

    let cancelContext = cancel ?? CancelContext()
    promise.cancelContext = cancelContext
    cancelContext.append(task: task, reject: reject!, description: PromiseDescription(promise))
    return promise
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
