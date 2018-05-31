//
//  after.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 4/28/18.
//

import Foundation
import PromiseKit

public func afterCC(seconds: TimeInterval) -> CancellablePromise<Void> {
    return at(time: DispatchTime.now() + seconds)
}

public func afterCC(_ interval: DispatchTimeInterval) -> CancellablePromise<Void> {
    return at(time: DispatchTime.now() + interval)
}

func at(time: DispatchTime) -> CancellablePromise<Void> {
#if swift(>=4.0)
    var fulfill: ((()) -> Void)!
#else
    var fulfill: (() -> Void)!
#endif
    var reject: ((Error) -> Void)!

    let promise = CancellablePromise<Void> { seal in
        fulfill = seal.fulfill
        reject = seal.reject
    }
    
    let task = DispatchWorkItem {
#if swift(>=4.0)
        fulfill(())
#else
        fulfill()
#endif
    }
    q.asyncAfter(deadline: time, execute: task)

    promise.appendCancellableTask(task: task, reject: reject)
    return promise
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
