//
//  when.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/16/18.
//

import Foundation
import Dispatch
import PromiseKit

private func _whenCC<U: Thenable>(_ whenPromise: Promise<Void>, fulfilled promises: [U], cancel: CancelContext? = nil) -> Promise<Void> {
    let cancelContext = cancel ?? CancelContext()
    whenPromise.cancelContext = cancelContext
    for p in promises where p.cancelContext != nil {
        cancelContext.append(context: p.cancelContext!)
    }
    return whenPromise
}

public func whenCC<U: Thenable>(fulfilled thenables: [U], cancel: CancelContext? = nil) -> Promise<[U.T]> {
    let rp: Promise<[U.T]> = when(fulfilled: thenables)
    let cancelContext = cancel ?? CancelContext()
    rp.cancelContext = cancelContext
    for t in thenables where t.cancelContext != nil {
        cancelContext.append(context: t.cancelContext!)
    }
    return rp
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable>(fulfilled promises: U..., cancel: CancelContext? = nil) -> Promise<Void> where U.T == Void {
    return _whenCC(when(fulfilled: promises), fulfilled: promises, cancel: cancel)
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable>(fulfilled promises: [U], cancel: CancelContext? = nil) -> Promise<Void> where U.T == Void {
    return _whenCC(when(fulfilled: promises), fulfilled: promises, cancel: cancel)
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable, V: Thenable>(fulfilled pu: U, _ pv: V, cancel: CancelContext? = nil) -> Promise<(U.T, V.T)> {
    let t = [pu.asVoid(), pv.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable, V: Thenable, W: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!, pw.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable, V: Thenable, W: Thenable, X: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T, X.T)> {
    return when(fulfilled: [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid()]).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!) }
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func whenCC<U: Thenable, V: Thenable, W: Thenable, X: Thenable, Y: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, _ py: Y, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T, X.T, Y.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid(), py.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!, py.value!) }
}

/**
 Generate promises at a limited rate and wait for all to fulfill.  Call 'cancel' on the returned promise to cancel all currently
 pending promises.

 For example:
 
     func downloadFile(url: URL) -> Promise<Data> {
         // ...
     }
 
     let urls: [URL] = /*…*/
     let urlGenerator = urls.makeIterator()

     let generator = AnyIterator<Promise<Data>> {
         guard url = urlGenerator.next() else {
             return nil
         }
         return downloadFile(url)
     }

     let promise = whenCC(generator, concurrently: 3).doneCC { datas in
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
public func whenCC<It: IteratorProtocol>(fulfilled promiseIterator: It, concurrently: Int, cancel: CancelContext? = nil) -> Promise<[It.Element.T]> where It.Element: Thenable {
    guard concurrently > 0 else {
        return Promise(error: PMKError.badInput)
    }

    var pi = promiseIterator
    var generatedPromises: [It.Element] = []
    var rootPromise: Promise<[It.Element.T]>!
    
    let generator = AnyIterator<It.Element> {
        let promise: It.Element! = pi.next()
        if let root = rootPromise {
            if let cc = promise.cancelContext {
                root.cancelContext?.append(context: cc)
            }
        } else {
            generatedPromises.append(promise)
        }
        return promise
    }
    
    rootPromise = when(fulfilled: generator, concurrently: concurrently)

    let cancelContext = cancel ?? CancelContext()
    rootPromise.cancelContext = cancelContext
    for p in generatedPromises where p.cancelContext != nil {
        cancelContext.append(context: p.cancelContext!)
    }
    return rootPromise
}

/**
 Waits on all provided promises.

 `whenCC(fulfilled:)` rejects as soon as one of the provided promises rejects. `whenCC(resolved:)` waits on all provided promises and *never*
 rejects.  When cancelled, all promises will attempt to be cancelled and those that are successfully cancelled will have a result of
 PromiseCancelledError.

     let context = CancelContext()
     whenCC(resolved: promise1, promise2, promise3, cancel: context).thenCC { results in
         for result in results where case .fulfilled(let value) {
            //…
         }
     }.catch { error in
         // invalid! Never rejects
     }
 
     //…

     context.cancel()
 
 - Returns: A new promise that resolves once all the provided promises resolve. The array is ordered the same as the input, ie. the result order is *not* resolution order.
 - Warning: The returned promise can only be rejected if cancelled.
 - Note: Any promises that error are implicitly consumed, your UnhandledErrorHandler will only be called for cancellation.
 - Remark: Doesn't take Thenable due to protocol associatedtype paradox
*/
public func whenCC<T>(resolved promises: Promise<T>..., cancel: CancelContext? = nil) -> Guarantee<[Result<T>]> {
    return whenCC(resolved: promises, cancel: cancel)
}

/// Waits on all provided promises.
public func whenCC<T>(resolved promises: [Promise<T>], cancel: CancelContext? = nil) -> Guarantee<[Result<T>]> {
    guard !promises.isEmpty else {
        return .value([])
    }

    let rg = when(resolved: promises)
    let cancelContext = cancel ?? CancelContext()
    rg.cancelContext = cancelContext
    for p in promises where p.cancelContext != nil {
        cancelContext.append(context: p.cancelContext!)
    }
    return rg
}

/// Waits on all provided Guarantees.
public func whenCC(_ guarantees: Guarantee<Void>..., cancel: CancelContext? = nil) -> Guarantee<Void> {
    return whenCC(guarantees: guarantees, cancel: cancel)
}

// Waits on all provided Guarantees.
public func whenCC(guarantees: [Guarantee<Void>], cancel: CancelContext? = nil) -> Guarantee<Void> {
    let rg = whenCC(fulfilled: guarantees, cancel: cancel)
    let cancelContext = cancel ?? CancelContext()
    rg.cancelContext = cancelContext
    for g in guarantees where g.cancelContext != nil {
        cancelContext.append(context: g.cancelContext!)
    }
    return rg.recover { _ in }.asVoid()
}
