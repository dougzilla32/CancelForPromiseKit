//
//  firstly.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import PromiseKit

public func firstly<V: CancellableThenable>(file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () throws -> V) -> CancellablePromise<V.U.T> {
    return CancellablePromise(firstlyCC(cancel: CancelContext(), file: file, function: function, line: line) { () throws -> V.U in
        return try body().thenable
    })
}

public func firstlyCC<U: Thenable>(file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () throws -> U) -> CancellablePromise<U.T> {
    return CancellablePromise(firstlyCC(cancel: CancelContext(), file: file, function: function, line: line, execute: body))
}

func firstlyCC<U: Thenable>(cancel: CancelContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () throws -> U) -> Promise<U.T> {
    do {
        let rv = try body()
        let rp = Promise<U.T>(rv)
        rp.cancelContext = cancel
        rp.appendCancelContext(from: rv)
        return rp
    } catch {
        return Promise(cancel: cancel, error: error)
    }
}

func firstlyCC<T>(cancel: CancelContext, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () -> Guarantee<T>) -> Promise<T> {
    let rv = body()
    let rp = Promise<T>(rv)
    rp.cancelContext = cancel
    rp.appendCancelContext(from: rv)
    return rp
}
