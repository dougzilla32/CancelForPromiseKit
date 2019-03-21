//
//  race.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/16/18.
//

@_exported import PromiseKit

/**
 Resolves with the first resolving cancellable promise from a set of cancellable promises. Calling `cancel` on the
 race promise cancels all pending promises.

     let racePromise = race(promise1, promise2, promise3).then { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new promise that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Warning: aborts if the array is empty.
*/
public func race<V: CancellableThenable>(_ thenables: V...) -> CancellablePromise<V.U.T> {
    return race(thenables)
}

/**
 Resolves with the first resolving promise from a set of promises. Calling `cancel` on the
 race promise cancels all pending promises.

     let racePromise = race(promise1, promise2, promise3).then { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new promise that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Remark: Returns promise rejected with PMKError.badInput if empty array provided
*/
public func race<V: CancellableThenable>(_ thenables: [V]) -> CancellablePromise<V.U.T> {
    guard !thenables.isEmpty else {
        return CancellablePromise(error: PMKError.badInput)
    }
    
    let promise = CancellablePromise(race(asThenables(thenables)))
    for t in thenables {
        promise.appendCancelContext(from: t)
    }
    return promise
}
