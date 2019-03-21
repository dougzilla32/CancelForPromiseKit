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

     let context = URLSession.shared.cancellableDataTask(url: url1).then {
         URLSession.shared.cancellableDataTask(url: url2)
     }.then {
         URLSession.shared.cancellableDataTask(url: url3)
     }.cancelContext
 
     // ...
 
     context.cancel()

 With:

     let context = firstly {
         URLSession.shared.cancellableDataTask(url: url1)
     }.then {
         URLSession.shared.cancellableDataTask(url: url2)
     }.then {
         URLSession.shared.cancellableDataTask(url: url3)
     }.cancelContext
 
     // ...
 
     context.cancel()

 - Note: the block you pass excecutes immediately on the current thread/queue.
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
