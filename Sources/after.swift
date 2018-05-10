//
//  after.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//

import Foundation
import PromiseKit

public func after(seconds: TimeInterval, cancel: CancelContext) -> Promise<Void> {
    return at(time: DispatchTime.now() + seconds, cancel: cancel)
}

public func after(_ interval: DispatchTimeInterval, cancel: CancelContext) -> Promise<Void> {
    return at(time: DispatchTime.now() + interval, cancel: cancel)
}

public func at(time: DispatchTime, cancel: CancelContext) -> Promise<Void> {
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

    cancel.append(task: task, reject: reject!)
    return promise
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
