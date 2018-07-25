//
//  firstly.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/10/18.
//

@_exported import PromiseKit

/**
 `firstly` for cancellable promises.

 Compare:

     let context = URLSession.shared.dataTaskCC(url: url1).then {
         URLSession.shared.dataTaskCC(url: url2)
     }.then {
         URLSession.shared.dataTaskCC(url: url3)
     }.cancelContext
 
     // ...
 
     context.cancel()

 With:

     let context = firstly {
         URLSession.shared.dataTaskCC(url: url1)
     }.then {
         URLSession.shared.dataTaskCC(url: url2)
     }.then {
         URLSession.shared.dataTaskCC(url: url3)
     }.cancelContext
 
     // ...
 
     context.cancel()

 - Note: the block you pass excecutes immediately on the current thread/queue.
 - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
 - See: firstly(execute: () -> Thenable)
*/
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

/**
 Varient of `firstly` that converts Thenable to CancellablePromise.
 
 - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
 */
public func firstlyCC<U: Thenable>(execute body: () throws -> U) -> CancellablePromise<U.T> {
    do {
        return CancellablePromise(try body())
    } catch {
        return CancellablePromise(error: error)
    }
}

/**
 Varient of `firstly` that converts Guarantee to CancellablePromise.
 
 - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
 */
public func firstlyCC<T>(execute body: () -> Guarantee<T>) -> CancellablePromise<T> {
    return CancellablePromise(body())
}
