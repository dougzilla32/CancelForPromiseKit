//
//  when.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/16/18.
//

import Foundation
import Dispatch
@_exported import PromiseKit

/**
 Wait for all promises in a set to fulfill.

 For example:

     let p = when(fulfilled: promise1, promise2).then { results in
         //…
     }.catch { error in
         switch error {
         case URLError.notConnectedToInternet:
             //…
         case CLError.denied:
             //…
         }
     }
 
     //…

     p.cancel()

 - Note: If *any* of the provided promises reject, the returned promise is immediately rejected with that error.
 - Warning: In the event of rejection the other promises will continue to resolve and, as per any other promise, will either fulfill or reject. This is the right pattern for `getter` style asynchronous tasks, but often for `setter` tasks (eg. storing data on a server), you most likely will need to wait on all tasks and then act based on which have succeeded and which have failed, in such situations use `when(resolved:)`.
 - Parameter promises: The promises upon which to wait before the returned promise resolves.
 - Returns: A new promise that resolves when all the provided promises fulfill or one of the provided promises rejects.
 - Note: `when` provides `NSProgress`.
 - SeeAlso: `when(resolved:)`
*/
public func when<V: CancellableThenable>(fulfilled thenables: [V]) -> CancellablePromise<[V.U.T]> {
    let rp = CancellablePromise(when(fulfilled: asThenables(thenables)))
    for t in thenables {
        rp.appendCancelContext(from: t)
    }
    return rp
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<V: CancellableThenable>(fulfilled promises: V...) -> CancellablePromise<Void> where V.U.T == Void {
    let rp = CancellablePromise(when(fulfilled: asThenables(promises)))
    for p in promises {
        rp.appendCancelContext(from: p)
    }
    return rp
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<V: CancellableThenable>(fulfilled promises: [V]) -> CancellablePromise<Void> where V.U.T == Void {
    let rp = CancellablePromise(when(fulfilled: asThenables(promises)))
    for p in promises {
        rp.appendCancelContext(from: p)
    }
    return rp
}

/**
 Wait for all promises in a set to fulfill, unless cancelled before completion.

 - Note: by convention this function should not have a 'cancellable' prefix, however the prefix is necessary due to a compiler bug exemplified by the following:
 
     ````
     This works fine:
       1  func hi(_: String...) { }
       2  func hi(_: String, _: String) { }
       3  hi("hi", "there")

     This does not compile:
       1  func hi(_: String...) { }
       2  func hi(_: String, _: String) { }
       3  func hi(_: Int...) { }
       4  func hi(_: Int, _: Int) { }
       5
       6  hi("hi", "there")  // Ambiguous use of 'hi' (lines 1 & 2 are candidates)
       7  hi(1, 2)           // Ambiguous use of 'hi' (lines 3 & 4 are candidates)
     ````
 */
public func cancellableWhen<U: CancellableThenable, V: CancellableThenable>(fulfilled pu: U, _ pv: V) -> CancellablePromise<(U.U.T, V.U.T)> {
    let t = [pu.asVoid(), pv.asVoid()]
    return when(fulfilled: t).map(on: nil) { (pu.value!, pv.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
/// - SeeAlso: `cancellableWhen(fulfilled:,_:)`
public func cancellableWhen<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W) -> CancellablePromise<(U.U.T, V.U.T, W.U.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid()]
    return when(fulfilled: t).map(on: nil) { (pu.value!, pv.value!, pw.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
/// - SeeAlso: `cancellableWhen(fulfilled:,_:)`
public func cancellableWhen<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable, X: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X) -> CancellablePromise<(U.U.T, V.U.T, W.U.T, X.U.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid()]
    return when(fulfilled: t).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
/// - SeeAlso: `cancellableWhen(fulfilled:,_:)`
public func cancellableWhen<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable, X: CancellableThenable, Y: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, _ py: Y) -> CancellablePromise<(U.U.T, V.U.T, W.U.T, X.U.T, Y.U.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid(), py.asVoid()]
    return when(fulfilled: t).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!, py.value!) }
}

/**
 Generate promises at a limited rate and wait for all to fulfill.  Call `cancel` on the returned promise to cancel all currently
 pending promises.

 For example:
 
     func downloadFile(url: URL) -> CancellablePromise<Data> {
         // ...
     }
 
     let urls: [URL] = /*…*/
     let urlGenerator = urls.makeIterator()

     let generator = AnyIterator<CancellablePromise<Data>> {
         guard url = urlGenerator.next() else {
             return nil
         }
         return downloadFile(url)
     }

     let promise = when(generator, concurrently: 3).done { datas in
         // ...
     }
 
     // ...
 
     promise.cancel()

 
 No more than three downloads will occur simultaneously.

 - Note: The generator is called *serially* on a *background* queue.
 - Warning: Refer to the warnings on `when(fulfilled:)`
 - Parameter promiseGenerator: Generator of promises.
 - Parameter cancel: Optional cancel context, overrides the default context.
 - Returns: A new promise that resolves when all the provided promises fulfill or one of the provided promises rejects.
 - SeeAlso: `when(resolved:)`
 */
public func when<It: IteratorProtocol>(fulfilled promiseIterator: It, concurrently: Int) -> CancellablePromise<[It.Element.U.T]> where It.Element: CancellableThenable {
    guard concurrently > 0 else {
        return CancellablePromise(error: PMKError.badInput)
    }
    
    var pi = promiseIterator
    var generatedPromises: [CancellablePromise<It.Element.U.T>] = []
    var rootPromise: CancellablePromise<[It.Element.U.T]>!
    
    let generator = AnyIterator<Promise<It.Element.U.T>> {
        guard let promise = pi.next() as? CancellablePromise<It.Element.U.T> else {
            return nil
        }
        if let root = rootPromise {
            root.appendCancelContext(from: promise)
        } else {
            generatedPromises.append(promise)
        }
        return promise.promise
    }
    
    rootPromise = CancellablePromise(when(fulfilled: generator, concurrently: concurrently))
    for p in generatedPromises {
        rootPromise.appendCancelContext(from: p)
    }
    return rootPromise
}

/**
 Waits on all provided promises.

 `when(fulfilled:)` rejects as soon as one of the provided promises rejects. `when(resolved:)` waits on all provided promises and *never*
 rejects.  When cancelled, all promises will attempt to be cancelled and those that are successfully cancelled will have a result of
 PMKError.cancelled.

     let p = when(resolved: promise1, promise2, promise3, cancel: context).then { results in
         for result in results where case .fulfilled(let value) {
            //…
         }
     }.catch { error in
         // invalid! Never rejects
     }
 
     //…

     p.cancel()
 
 - Returns: A new promise that resolves once all the provided promises resolve. The array is ordered the same as the input, ie. the result order is *not* resolution order.
 - Note: Any promises that error are implicitly consumed.
 - Remark: Doesn't take CancellableThenable due to protocol associatedtype paradox
*/
public func when<T>(resolved promises: CancellablePromise<T>...) -> CancellablePromise<[Result<T>]> {
    return when(resolved: promises)
}

/// Waits on all provided promises.
/// - SeeAlso: `when(resolved:)`
public func when<T>(resolved promises: [CancellablePromise<T>]) -> CancellablePromise<[Result<T>]> {
    let rp = CancellablePromise(when(resolved: asPromises(promises)))
    for p in promises {
        rp.appendCancelContext(from: p)
    }
    return rp
}

func asThenables<V: CancellableThenable>(_ cancellableThenables: [V]) -> [V.U] {
    var thenables: [V.U] = []
    for ct in cancellableThenables {
        thenables.append(ct.thenable)
    }
    return thenables
}

func asPromises<T>(_ cancellablePromises: [CancellablePromise<T>]) -> [Promise<T>] {
    var promises = [Promise<T>]()
    for cp in cancellablePromises {
        promises.append(cp.promise)
    }
    return promises
}
