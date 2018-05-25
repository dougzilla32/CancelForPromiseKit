//
//  CancellableCatchable.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/22/18.
//

import Dispatch
import PromiseKit

public protocol CancellableCatchMixin: CancellableThenable {
    associatedtype M: CatchMixin

    var catchable: M { get }
}

public extension CancellableCatchMixin {
    @discardableResult
    func `catch`(on: DispatchQueue? = conf.Q.return, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) -> Void) -> CPKFinalizer {
        return catchable.catchCC(on: on, policy: policy, file: file, function: function, line: line, body)
    }
    
    func recover<V: CancellableThenable>(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> V) -> CancellablePromise<M.T> where V.U.T == M.T {
        return CancellablePromise(catchable.recoverCC(on: on, policy: policy, file: file, function: function, line: line) { (error: Error) throws -> Promise<V.U.T> in
            return try body(error).thenable as! Promise<V.U.T>
        })
    }
    
    func ensure(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> Void) -> CancellablePromise<M.T> {
        return CancellablePromise(catchable.ensureCC(on: on, file: file, function: function, line: line, body))
    }
    
    func ensureThen(on: DispatchQueue? = conf.Q.return, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping () -> CancellablePromise<Void>) -> CancellablePromise<M.T> {
        return CancellablePromise(catchable.ensureThenCC(on: on, file: file, function: function, line: line) { () -> Promise<Void> in
            return body().promise
        })
    }
    
    func cauterize(file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        catchable.cauterizeCC(file: file, function: function, line: line)
    }
}

extension CancellableCatchMixin where M.T == Void {
    func recoverCC(on: DispatchQueue? = conf.Q.map, policy: CatchPolicy = conf.catchPolicy, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, _ body: @escaping(Error) throws -> Void) -> CancellablePromise<Void> {
        return CancellablePromise(catchable.recoverCC(on: on, policy: policy, file: file, function: function, line: line) { error in
            try body(error)
        })
    }
}
