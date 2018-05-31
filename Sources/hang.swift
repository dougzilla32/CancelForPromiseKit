//
//  hang.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/16/18.
//

import PromiseKit

public func hang<T>(_ promise: CancellablePromise<T>) throws -> T {
    return try hang(promise.promise)
}
