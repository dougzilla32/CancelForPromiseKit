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

/**
 Resolves with the first resolving Guarantee from a set of cancellable guarantees. Calling `cancel` on the
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
public func race<T>(_ guarantees: CancellableGuarantee<T>..., cancelValue: T? = nil) -> CancellableGuarantee<T> {
    let guarantee = CancellableGuarantee(race(asGuarantees(guarantees)), cancelValue: cancelValue)
    for g in guarantees {
        guarantee.appendCancelContext(from: g)
    }
    return guarantee
}

private func race<T>(_ gs: [Guarantee<T>]) -> Guarantee<T> {
    let guarantee: Guarantee<T>
    switch gs.count {
    case 0:
        guarantee = race()
    case 1:
        guarantee = race(gs[0])
    case 2:
        guarantee = race(gs[0], gs[1])
    case 3:
        guarantee = race(gs[0], gs[1], gs[2])
    case 4:
        guarantee = race(gs[0], gs[1], gs[2], gs[3])
    case 5:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4])
    case 6:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4], gs[5])
    case 7:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4], gs[5], gs[6])
    case 8:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4], gs[5], gs[6], gs[7])
    case 9:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4], gs[5], gs[6], gs[7], gs[8])
    case 10:
        guarantee = race(gs[0], gs[1], gs[2], gs[3], gs[4], gs[5], gs[6], gs[7], gs[8], gs[9])
    default:
        precondition(false, "Can only race up to 10 cancellable guarantees: \(gs.count)")
        guarantee = Guarantee.pending().guarantee  // to make the compiler happy
    }
    return guarantee
}

/// - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
public func raceCC<U: Thenable>(_ thenables: U...) -> CancellablePromise<U.T> {
    return CancellablePromise(race(thenables))
}

/// - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
public func raceCC<U: Thenable>(_ thenables: [U]) -> CancellablePromise<U.T> {
    return CancellablePromise(race(thenables))
}

/// - Note: Methods with the `CC` suffix create a new CancellablePromise, and those without the `CC` suffix accept an existing CancellablePromise.
public func raceCC<T>(_ guarantees: Guarantee<T>..., cancelValue: T? = nil) -> CancellableGuarantee<T> {
    return CancellableGuarantee(race(guarantees), cancelValue: cancelValue)
}
