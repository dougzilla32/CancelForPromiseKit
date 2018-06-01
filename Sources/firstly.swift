//
//  firstly.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/10/18.
//

import PromiseKit

public func firstly<V: CancellableThenable>(execute body: () throws -> V) -> CancellablePromise<V.U.T> {
    do {
        let rv = try body()
        let rp = CancellablePromise<V.U.T>(rv.thenable)
        rp.appendCancelContext(from: rv)
        return rp
    } catch {
        return CancellablePromise(error: error)
    }
}

public func firstlyCC<U: Thenable>(execute body: () throws -> U) -> CancellablePromise<U.T> {
    do {
        return CancellablePromise(try body())
    } catch {
        return CancellablePromise(error: error)
    }
}

public func firstlyCC<T>(execute body: () -> Guarantee<T>) -> CancellablePromise<T> {
    return CancellablePromise(body())
}
