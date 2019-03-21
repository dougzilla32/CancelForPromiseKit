//
//  after.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 4/28/18.
//

import struct Foundation.TimeInterval
import Dispatch


/// Extend DispatchWorkItem to be a CancellableTask
extension DispatchWorkItem: CancellableTask { }

/**
     cancellableAfter(seconds: 1.5).then {
         //…
     }

- Returns: A guarantee that resolves after the specified duration.
*/
public func cancellableAfter(seconds: TimeInterval) -> CancellablePromise<Void> {
    let (rp, seal) = CancellablePromise<Void>.pending()
    let when = DispatchTime.now() + seconds

    let task = DispatchWorkItem {
#if swift(>=4.0)
        seal.fulfill(())
#else
        seal.fulfill()
#endif
    }

    q.asyncAfter(deadline: when, execute: task)
    rp.appendCancellableTask(task, reject: seal.reject)
    return rp
}

/**
     cancellableAfter(.seconds(2)).then {
         //…
     }

 - Returns: A guarantee that resolves after the specified duration.
*/
public func cancellableAfter(_ interval: DispatchTimeInterval) -> CancellablePromise<Void> {
    let (rp, seal) = CancellablePromise<Void>.pending()
    let when = DispatchTime.now() + interval

    let task = DispatchWorkItem {
#if swift(>=4.0)
        seal.fulfill(())
#else
        seal.fulfill()
#endif
    }
    
    q.asyncAfter(deadline: when, execute: task)
    rp.appendCancellableTask(task, reject: seal.reject)
    return rp
}

private var q: DispatchQueue {
    if #available(macOS 10.10, iOS 8.0, tvOS 9.0, watchOS 2.0, *) {
        return DispatchQueue.global(qos: .default)
    } else {
        return DispatchQueue.global(priority: .default)
    }
}
