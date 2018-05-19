//
//  race.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/16/18.
//

import PromiseKit

/**
 Resolves with the first resolving promise from a set of promises. Calling 'cancel' on the
 race promise cancels all pending promises.

     let racePromise = raceCC(promise1, promise2, promise3).thenCC { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new promise that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Warning: aborts if the array is empty.
*/
public func raceCC<U: Thenable>(_ thenables: U..., cancel: CancelContext? = nil) -> Promise<U.T> {
    let promise = race(thenables)
    let cancelContext = cancel ?? CancelContext()
    promise.cancelContext = cancelContext
    for p in thenables where p.cancelContext != nil {
        cancelContext.append(context: p.cancelContext!)
    }
    return promise
}

/**
 Resolves with the first resolving promise from a set of promises. Calling 'cancel' on the
 race promise cancels all pending promises.

     let racePromise = raceCC(promise1, promise2, promise3).thenCC { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new promise that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Remark: Returns promise rejected with PMKError.badInput if empty array provided
*/
public func raceCC<U: Thenable>(_ thenables: [U], cancel: CancelContext? = nil) -> Promise<U.T> {
    guard !thenables.isEmpty else {
        return Promise(error: PMKError.badInput)
    }

    return raceCC(thenables)
}

/**
 Resolves with the first resolving Guarantee from a set of promises. Calling 'cancel' on the
 race promise cancels all pending promises.

     let racePromise = raceCC(promise1, promise2, promise3).thenCC { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new guarantee that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Remark: Returns promise rejected with PMKError.badInput if empty array provided
*/
public func raceCC<T>(_ guarantees: Guarantee<T>..., cancel: CancelContext? = nil) -> Promise<T> {
    let guarantee = race(guarantees)
    let cancelContext = cancel ?? CancelContext()
    guarantee.cancelContext = cancelContext
    for g in guarantees where g.cancelContext != nil {
        cancelContext.append(context: g.cancelContext!)
    }
    return guarantee
}
