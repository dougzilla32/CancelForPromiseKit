//
//  when.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/16/18.
//

import Foundation
import Dispatch
import PromiseKit

func asThenables<V: CancellableThenable>(_ cancellableThenables: [V]) -> [V.U] {
    var thenables = [V.U]()
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

func asGuarantees<T>(_ cancellableGuarantees: [CancellableGuarantee<T>]) -> [Guarantee<T>] {
    var guarantees = [Guarantee<T>]()
    for cg in cancellableGuarantees {
        guarantees.append(cg.guarantee)
    }
    return guarantees
}

public func when<V: CancellableThenable>(fulfilled thenables: [V]) -> CancellablePromise<[V.U.T]> {
    return CancellablePromise(whenCC(fulfilled: asThenables(thenables)))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<V: CancellableThenable>(fulfilled promises: V...) -> CancellablePromise<Void> where V.U.T == Void {
    return CancellablePromise(whenCC(fulfilled: asThenables(promises)))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<V: CancellableThenable>(fulfilled promises: [V]) -> CancellablePromise<Void> where V.U.T == Void {
    return CancellablePromise(whenCC(fulfilled: asThenables(promises)))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<U: CancellableThenable, V: CancellableThenable>(fulfilled pu: U, _ pv: V) -> CancellablePromise<(U.U.T, V.U.T)> {
    return CancellablePromise(whenCC(fulfilled: pu.thenable, pv.thenable))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W) -> CancellablePromise<(U.U.T, V.U.T, W.U.T)> {
    return CancellablePromise(whenCC(fulfilled: pu.thenable, pv.thenable, pw.thenable))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable, X: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X) -> CancellablePromise<(U.U.T, V.U.T, W.U.T, X.U.T)> {
    return CancellablePromise(whenCC(fulfilled: pu.thenable, pv.thenable, pw.thenable, px.thenable))
}

/// Wait for all promises in a set to fulfill, unless cancelled before completion.
public func when<U: CancellableThenable, V: CancellableThenable, W: CancellableThenable, X: CancellableThenable, Y: CancellableThenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, _ py: Y) -> CancellablePromise<(U.U.T, V.U.T, W.U.T, X.U.T, Y.U.T)> {
    return CancellablePromise(whenCC(fulfilled: pu.thenable, pv.thenable, pw.thenable, px.thenable, py.thenable))
}

/**
 Generate promises at a limited rate and wait for all to fulfill.  Call 'cancel' on the returned promise to cancel all currently
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
public func when<It: IteratorProtocol>(fulfilled promiseIterator: It, concurrently: Int) -> CancellablePromise<[It.Element.U.T]> where It.Element: CancellableThenable {
    guard concurrently > 0 else {
        return CancellablePromise(error: PMKError.badInput)
    }
    
    var pi = promiseIterator
    var generatedPromises: [Promise<It.Element.U.T>] = []
    var rootPromise: Promise<[It.Element.U.T]>!
    
    let generator = AnyIterator<Promise<It.Element.U.T>> {
        guard let promise = pi.next()?.thenable as? Promise<It.Element.U.T> else {
            return nil
        }
        if let root = rootPromise {
            root.appendCancelContext(from: promise)
        } else {
            generatedPromises.append(promise)
        }
        return promise
    }
    
    rootPromise = when(fulfilled: generator, concurrently: concurrently)
    
    rootPromise.cancelContext = CancelContext()
    for p in generatedPromises where p.cancelContext != nil {
        rootPromise.appendCancelContext(from: p)
    }
    return CancellablePromise(rootPromise)
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
 - Remark: Doesn't take CancellableThenable due to protocol associatedtype paradox
*/
public func when<T>(resolved promises: CancellablePromise<T>...) -> CancellableGuarantee<[Result<T>]> {
    return CancellableGuarantee(whenCC(resolved: asPromises(promises)))
}

/// Waits on all provided promises.
public func when<T>(resolved promises: [CancellablePromise<T>]) -> CancellableGuarantee<[Result<T>]> {
    return CancellableGuarantee(whenCC(resolved: asPromises(promises)))
}

/// Waits on all provided Guarantees.
public func when(_ guarantees: CancellableGuarantee<Void>...) -> CancellableGuarantee<Void> {
    return CancellableGuarantee(whenCC(guarantees: asGuarantees(guarantees)))
}

/// Waits on all provided Guarantees.
public func when(guarantees: [CancellableGuarantee<Void>]) -> CancellableGuarantee<Void> {
    return CancellableGuarantee(whenCC(guarantees: asGuarantees(guarantees)))
}

// MARK: whenCC

private func _whenCC<U: Thenable>(_ whenPromise: Promise<Void>, fulfilled promises: [U], cancel: CancelContext? = nil) -> Promise<Void> {
    whenPromise.cancelContext = cancel ?? CancelContext()
    for p in promises {
        whenPromise.appendCancelContext(from: p)
    }
    return whenPromise
}

func whenCC<U: Thenable>(fulfilled thenables: [U], cancel: CancelContext? = nil) -> Promise<[U.T]> {
    let rp: Promise<[U.T]> = when(fulfilled: thenables)
    rp.cancelContext = cancel ?? CancelContext()
    for t in thenables where t.cancelContext != nil {
        rp.appendCancelContext(from: t)
    }
    return rp
}

func whenCC<U: Thenable>(fulfilled promises: U..., cancel: CancelContext? = nil) -> Promise<Void> where U.T == Void {
    return _whenCC(when(fulfilled: promises), fulfilled: promises, cancel: cancel)
}

func whenCC<U: Thenable>(fulfilled promises: [U], cancel: CancelContext? = nil) -> Promise<Void> where U.T == Void {
    return _whenCC(when(fulfilled: promises), fulfilled: promises, cancel: cancel)
}

func whenCC<U: Thenable, V: Thenable>(fulfilled pu: U, _ pv: V, cancel: CancelContext? = nil) -> Promise<(U.T, V.T)> {
    let t = [pu.asVoid(), pv.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!) }
}

func whenCC<U: Thenable, V: Thenable, W: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!, pw.value!) }
}

func whenCC<U: Thenable, V: Thenable, W: Thenable, X: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T, X.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!) }
}

func whenCC<U: Thenable, V: Thenable, W: Thenable, X: Thenable, Y: Thenable>(fulfilled pu: U, _ pv: V, _ pw: W, _ px: X, _ py: Y, cancel: CancelContext? = nil) -> Promise<(U.T, V.T, W.T, X.T, Y.T)> {
    let t = [pu.asVoid(), pv.asVoid(), pw.asVoid(), px.asVoid(), py.asVoid()]
    return _whenCC(when(fulfilled: t), fulfilled: t, cancel: cancel).map(on: nil) { (pu.value!, pv.value!, pw.value!, px.value!, py.value!) }
}

func whenCC<It: IteratorProtocol>(fulfilled promiseIterator: It, concurrently: Int, cancel: CancelContext? = nil) -> Promise<[It.Element.T]> where It.Element: Thenable {
    guard concurrently > 0 else {
        return Promise(error: PMKError.badInput)
    }

    var pi = promiseIterator
    var generatedPromises: [It.Element] = []
    var rootPromise: Promise<[It.Element.T]>!
    
    let generator = AnyIterator<It.Element> {
        guard let promise = pi.next() else {
            return nil
        }
        if let root = rootPromise {
            root.appendCancelContext(from: promise)
        } else {
            generatedPromises.append(promise)
        }
        return promise
    }
    
    rootPromise = when(fulfilled: generator, concurrently: concurrently)

    rootPromise.cancelContext = cancel ?? CancelContext()
    for p in generatedPromises {
        rootPromise.appendCancelContext(from: p)
    }
    return rootPromise
}

func whenCC<T>(resolved promises: Promise<T>..., cancel: CancelContext? = nil) -> Guarantee<[Result<T>]> {
    return whenCC(resolved: promises, cancel: cancel)
}

func whenCC<T>(resolved promises: [Promise<T>], cancel: CancelContext? = nil) -> Guarantee<[Result<T>]> {
    guard !promises.isEmpty else {
        return .value([])
    }

    let rg = when(resolved: promises)
    rg.cancelContext = cancel ?? CancelContext()
    for p in promises {
        rg.appendCancelContext(from: p)
    }
    return rg
}

func whenCC(_ guarantees: Guarantee<Void>..., cancel: CancelContext? = nil) -> Guarantee<Void> {
    return whenCC(guarantees: guarantees, cancel: cancel)
}

func whenCC(guarantees: [Guarantee<Void>], cancel: CancelContext? = nil) -> Guarantee<Void> {
    let rg = whenCC(fulfilled: guarantees, cancel: cancel)
    rg.cancelContext = cancel ?? CancelContext()
    for g in guarantees {
        rg.appendCancelContext(from: g)
    }
    return rg.recover { _ in }.asVoid()
}
