//
//  race.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/16/18.
//

import PromiseKit

/**
 Resolves with the first resolving cancellable promise from a set of cancellable promises. Calling 'cancel' on the
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
    return CancellablePromise(raceCC(asThenables(thenables)))
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
public func race<V: CancellableThenable>(_ thenables: [V]) -> CancellablePromise<V.U.T> {
    return CancellablePromise(raceCC(asThenables(thenables)))
}

/**
 Resolves with the first resolving Guarantee from a set of cancellable guarantees. Calling 'cancel' on the
 race promise cancels all pending guarantees.

     let racePromise = race(guarantee1, guarantee2, guarantee3).then { winner in
         //…
     }
 
     //…
 
     racePromise.cancel()

 - Returns: A new guarantee that resolves when the first promise in the provided promises resolves.
 - Warning: If any of the provided promises reject, the returned promise is rejected.
 - Remark: Returns promise rejected with PMKError.badInput if empty array provided
*/
public func race<T>(_ guarantees: CancellableGuarantee<T>...) -> CancellablePromise<T> {
    return CancellablePromise(raceCC(asGuarantees(guarantees)))
}

func raceCC<U: Thenable>(_ thenables: U..., cancel: CancelContext? = nil) -> Promise<U.T> {
    return raceCC(thenables, cancel: cancel)
}

func raceCC<U: Thenable>(_ thenables: [U], cancel: CancelContext? = nil) -> Promise<U.T> {
    guard !thenables.isEmpty else {
        return Promise(cancel: CancelContext(), error: PMKError.badInput)
    }

    let promise = race(thenables)
    promise.cancelContext = cancel ?? CancelContext()
    for t in thenables {
        promise.appendCancelContext(from: t)
    }
    return promise
}

func raceCC<T>(_ guarantees: Guarantee<T>..., cancel: CancelContext? = nil) -> Promise<T> {
    let guarantee = race(guarantees)
    guarantee.cancelContext = cancel ?? CancelContext()
    for g in guarantees {
        guarantee.appendCancelContext(from: g)
    }
    return guarantee
}
