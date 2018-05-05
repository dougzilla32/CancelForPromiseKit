//
//  CancellablePromise.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import PromiseKit

public extension Promise {
//    public class func value(_ value: T, cancel: CancelContext) -> Promise<T> {
//        let task = DispatchWorkItemTask()
//        var reject: ((Error) -> Void)?
//
//        let promise = Promise<T> { seal in
//            reject = seal.reject
//            task.task = DispatchWorkItem() {
//                seal.fulfill(value)
//            }
//            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now(), execute: task.task!)
//        }
//
//        cancel.append(task: task, reject: reject)
//        return promise
//    }
 
    public convenience init(cancel: CancelContext, resolver body: @escaping (Resolver<T>) throws -> Void) {
        var reject: ((Error) -> Void)?
        self.init() { seal in
            reject = seal.reject
            try body(seal)
        }
        cancel.append(reject: reject)
    }
    
    public convenience init(cancel: CancelContext, task: CancellableTask, resolver body: @escaping (Resolver<T>) throws -> Void) {
        self.init(cancel: cancel, resolver: body)
        cancel.replaceLast(task: task)
    }
}
