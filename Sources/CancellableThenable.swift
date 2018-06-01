//
//  CancellableThenable.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/11/18.
//

import PromiseKit

public protocol CancellableThenable: class {
    associatedtype U: Thenable
    
    var thenable: U { get }

    var cancelContext: CancelContext { get }
    
    var cancelItems: CancelItemList { get }
}

struct CancelContextKey {
    public static var cancelContext: UInt8 = 0
    public static var cancelItems: UInt8 = 0
}

public extension CancellableThenable {
    func appendCancellableTask(task: CancellableTask?, reject: ((Error) -> Void)?) {
        self.cancelContext.append(task: task, reject: reject, thenable: self)
    }
    
    func appendCancelContext<Z: CancellableThenable>(from: Z) {
        self.cancelContext.append(context: from.cancelContext, thenable: self)
    }
    
    func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.cancelContext.cancel(error: error, file: file, function: function, line: line)
    }
    
    var isCancelled: Bool {
        return self.cancelContext.isCancelled
    }
    
    var cancelAttempted: Bool {
        return self.cancelContext.cancelAttempted
    }
    
    var cancelledError: Error? {
        return self.cancelContext.cancelledError
    }
    
    func then<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, line: UInt = #line, _ body: @escaping (U.T) throws -> V) -> CancellablePromise<V.U.T> {

        let description = PromiseDescription<V.U.T>()
        let cancelItems = CancelItemList()
        
        let cancelBody = { (value: U.T) throws -> V.U in
            if let error = self.cancelContext.cancelledError {
                throw error
            } else {
                self.cancelContext.removeItems(self.cancelItems, clearList: true)
                
                let rv = try body(value)
                self.cancelContext.append(context: rv.cancelContext, description: description, cancelItems: cancelItems)
                return rv.thenable
            }
        }
        
        let promise = self.thenable.then(on: on, file: file, line: line, cancelBody)
        description.promise = promise
        return CancellablePromise(promise, context: self.cancelContext, cancelItems: cancelItems)
    }
    
    func then<V: Thenable>(on: DispatchQueue? = conf.Q.map, file: StaticString = #file, line: UInt = #line, _ body: @escaping (U.T) throws -> V) -> CancellablePromise<V.T> {
        let cancelBody = { (value: U.T) throws -> V in
            if let error = self.cancelContext.cancelledError {
                throw error
            } else {
                self.cancelContext.removeItems(self.cancelItems, clearList: true)
                return try body(value)
            }
        }
        
        let promise = self.thenable.then(on: on, file: file, line: line, cancelBody)
        return CancellablePromise(promise, context: self.cancelContext)
    }
    
    func map<V>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping (U.T) throws -> V) -> CancellablePromise<V> {
        let cancelTransform = { (value: U.T) throws -> V in
            if let error = self.cancelContext.cancelledError {
                throw error
            } else {
                self.cancelContext.removeItems(self.cancelItems, clearList: true)
                return try transform(value)
            }
        }
        
        let promise = self.thenable.map(on: on, cancelTransform)
        return CancellablePromise(promise, context: self.cancelContext)
    }
    
    func compactMap<V>(on: DispatchQueue? = conf.Q.map, _ transform: @escaping (U.T) throws -> V?) -> CancellablePromise<V> {
        let cancelTransform = { (value: U.T) throws -> V? in
            if let error = self.cancelContext.cancelledError {
                throw error
            } else {
                self.cancelContext.removeItems(self.cancelItems, clearList: true)
                return try transform(value)
            }
        }
        
        let promise = self.thenable.compactMap(on: on, cancelTransform)
        return CancellablePromise(promise, context: self.cancelContext)
    }
    
    func done(on: DispatchQueue? = conf.Q.return, _ body: @escaping (U.T) throws -> Void) -> CancellablePromise<Void> {
        let cancelBody = { (value: U.T) throws -> Void in
            if let error = self.cancelContext.cancelledError {
                throw error
            } else {
                self.cancelContext.removeItems(self.cancelItems, clearList: true)
                try body(value)
            }
        }
        
        let promise = self.thenable.done(on: on, cancelBody)
        return CancellablePromise(promise, context: self.cancelContext)
    }
    
    func get(on: DispatchQueue? = conf.Q.return, _ body: @escaping (U.T) throws -> Void) -> CancellablePromise<U.T> {
        return map(on: on) {
            try body($0)
            return $0
        }
    }

    /// - Returns: a new promise chained off this promise but with its value discarded.
    func asVoid() -> CancellablePromise<Void> {
        return map(on: nil) { _ in }
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

extension Optional where Wrapped: DispatchQueue {
    func async(_ body: @escaping() -> Void) {
        switch self {
        case .none:
            body()
        case .some(let q):
            q.async(execute: body)
        }
    }
}
