//
//  hang.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/16/18.
//

import PromiseKit

public func hang<T>(_ promise: CancellablePromise<T>) throws -> T {
    return try hang(promise.promise)
}

func hangCC<T>(_ promise: Promise<T>) throws -> T {
    return try hang(promise)
}
