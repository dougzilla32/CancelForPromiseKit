//
//  CancellableThenable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/22/18.
//

import PromiseKit

public protocol CancellableThenable: class {
    associatedtype U: Thenable
    
    var thenable: U { get }
}

public extension CancellableThenable {
    var cancelContext: CancelContext! {
        get {
            return thenable.cancelContext
        }
        
        set {
            thenable.cancelContext = newValue
        }
    }
    
    func appendCancellableTask(task: CancellableTask?, reject: ((Error) -> Void)?) {
        thenable.cancelContext?.append(task: task, reject: reject, thenable: thenable)
    }
    
    func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelContext?.cancel(error: error, file: file, function: function, line: line)
    }
    
    var isCancelled: Bool {
        return cancelContext?.isCancelled ?? false
    }
    
    var cancelAttempted: Bool {
        return cancelContext?.cancelAttempted ?? false
    }
    
    var cancelledError: Error? {
        return cancelContext?.cancelledError
    }
    
    func then<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (U.T) throws -> V) -> CancellablePromise<V.U.T> {
        return CancellablePromise(thenable.thenCC(on: on, file: file, function: function, line: line) { (value: U.T) throws -> Promise<V.U.T> in
            return try body(value).thenable as! Promise<V.U.T>
        })
    }
    
    func then<V: Thenable>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (U.T) throws -> V) -> CancellablePromise<V.T> {
        return CancellablePromise(thenable.thenCC(on: on, file: file, function: function, line: line) { (value: U.T) throws -> Promise<V.T> in
            return try body(value) as! Promise<V.T>
        })
    }
    
    func map<V>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping (U.T) throws -> V) -> CancellablePromise<V> {
        return CancellablePromise(thenable.mapCC(on: on, file: file, function: function, line: line, transform))
    }
    
    func compactMap<V>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ transform: @escaping (U.T) throws -> V?) -> CancellablePromise<V> {
        return CancellablePromise(thenable.compactMapCC(on: on, file: file, function: function, line: line, transform))
    }
    
    func done(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (U.T) throws -> Void) -> CancellablePromise<Void> {
        return CancellablePromise(thenable.doneCC(on: on, file: file, function: function, line: line, body))
    }
    
    func get(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping (U.T) throws -> Void) -> CancellablePromise<U.T> {
        return CancellablePromise(thenable.getCC(on: on, file: file, function: function, line: line, body))
    }
}

public extension CancellableThenable {
    /**
     - Returns: The error with which this promise was rejected; `nil` if this promise is not rejected.
     */
    var error: Error? {
        return thenable.error
    }

    /**
     - Returns: `true` if the promise has not yet resolved.
     */
    var isPending: Bool {
        return thenable.isPending
    }

    /**
     - Returns: `true` if the promise has resolved.
     */
    var isResolved: Bool {
        return thenable.isResolved
    }

    /**
     - Returns: `true` if the promise was fulfilled.
     */
    var isFulfilled: Bool {
        return thenable.isFulfilled
    }

    /**
     - Returns: `true` if the promise was rejected.
     */
    var isRejected: Bool {
        return thenable.isRejected
    }

    /**
     - Returns: The value with which this promise was fulfilled or `nil` if this promise is pending or rejected.
     */
    var value: U.T? {
        return thenable.value
    }
}

public extension CancellableThenable where U.T: Sequence {
    /**
     `CancellablePromise<[U.T]>` => `U.T` -> `V` => `CancellablePromise<[V]>`

         firstly {
             .value([1,2,3])
         }.mapValues { integer in
             integer * 2
         }.done {
             // $0 => [2,4,6]
         }
     */
    func mapValues<V>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V]> {
        return map(on: on) { try $0.map(transform) }
    }

    /**
     `CancellablePromise<[U.T]>` => `U.T` -> `[V]` => `CancellablePromise<[V]>`

         firstly {
             .value([1,2,3])
         }.flatMapValues { integer in
             [integer, integer]
         }.done {
             // $0 => [1,1,2,2,3,3]
         }
     */
    func flatMapValues<V: Sequence>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V.Iterator.Element]> {
        return map(on: on) { (foo: U.T) in
            try foo.flatMap { try transform($0) }
        }
    }

    /**
     `CancellablePromise<[U.T]>` => `U.T` -> `V?` => `CancellablePromise<[V]>`

         firstly {
             .value(["1","2","a","3"])
         }.compactMapValues {
             Int($0)
         }.done {
             // $0 => [1,2,3]
         }
     */
    func compactMapValues<V>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V?) -> CancellablePromise<[V]> {
        return map(on: on) { foo -> [V] in
          #if !swift(>=3.3) || (swift(>=4) && !swift(>=4.1))
            return try foo.flatMap(transform)
          #else
            return try foo.compactMap(transform)
          #endif
        }
    }

    /**
     `CancellablePromise<[U.T]>` => `U.T` -> `CancellablePromise<V>` => `CancellablePromise<[V]>`

         firstly {
             .value([1,2,3])
         }.thenMap { integer in
             .value(integer * 2)
         }.done {
             // $0 => [2,4,6]
         }
     */
    func thenMap<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V.U.T]> {
        return then(on: on) {
            when(fulfilled: try $0.map(transform))
        }
    }

    func thenMap<V: Thenable>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V.T]> {
        return then(on: on) {
            when(fulfilled: try $0.map(transform))
        }
    }
    
    /**
     `CancellablePromise<[T]>` => `T` -> `CancellablePromise<[U]>` => `CancellablePromise<[U]>`

         firstly {
             .value([1,2,3])
         }.thenFlatMap { integer in
             .value([integer, integer])
         }.done {
             // $0 => [1,1,2,2,3,3]
         }
     */
    func thenFlatMap<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V.U.T.Iterator.Element]> where V.U.T: Sequence {
        return then(on: on) {
            when(fulfilled: try $0.map(transform))
        }.map(on: nil) {
            $0.flatMap { $0 }
        }
    }

    func thenFlatMap<V: Thenable>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping(U.T.Iterator.Element) throws -> V) -> CancellablePromise<[V.T.Iterator.Element]> where V.T: Sequence {
        return then(on: on) {
            when(fulfilled: try $0.map(transform))
        }.map(on: nil) {
            $0.flatMap { $0 }
        }
    }
    
    /**
     `CancellablePromise<[T]>` => `T` -> Bool => `CancellablePromise<[U]>`

         firstly {
             .value([1,2,3])
         }.filterValues {
             $0 > 1
         }.done {
             // $0 => [2,3]
         }
     */
    func filterValues(on: DispatchQueue? = conf.Q.map, _ isIncluded: @escaping (U.T.Iterator.Element) -> Bool) -> CancellablePromise<[U.T.Iterator.Element]> {
        return map(on: on) {
            $0.filter(isIncluded)
        }
    }
}

public extension CancellableThenable where U.T: Collection {
    /// - Returns: a promise fulfilled with the first value of this `Collection` or, if empty, a promise rejected with PMKError.emptySequence.
    var firstValue: CancellablePromise<U.T.Iterator.Element> {
        return map(on: nil) { aa in
            if let a1 = aa.first {
                return a1
            } else {
                throw PMKError.emptySequence
            }
        }
    }

    /// - Returns: a promise fulfilled with the last value of this `Collection` or, if empty, a promise rejected with PMKError.emptySequence.
    var lastValue: CancellablePromise<U.T.Iterator.Element> {
        return map(on: nil) { aa in
            if aa.isEmpty {
                throw PMKError.emptySequence
            } else {
                let i = aa.index(aa.endIndex, offsetBy: -1)
                return aa[i]
            }
        }
    }
}

public extension CancellableThenable where U.T: Sequence, U.T.Iterator.Element: Comparable {
    /// - Returns: a promise fulfilled with the sorted values of this `Sequence`.
    func sortedValues(on: DispatchQueue? = conf.Q.map) -> CancellablePromise<[U.T.Iterator.Element]> {
        return map(on: on) { $0.sorted() }
    }
}
