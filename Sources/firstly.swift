//
//  firstly.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/10/18.
//

import PromiseKit

public func firstlyCC<U: Thenable>(cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () throws -> U) -> Promise<U.T> {
    do {
        let rv = try body()
        if cancel == nil && rv.cancelContext == nil {
            ErrorConditions.firstlyCancelContextMissing(file: file, function: function, line: line)
        }
        if let c = cancel, let rvc = rv.cancelContext {
            c.append(context: rvc)
        }
        
        let rp = Promise<U.T>(rv)
        rp.cancelContext = cancel ?? rv.cancelContext ?? CancelContext()
        return rp
    } catch {
        return Promise(error: error)
    }
}

public func firstlyCC<T>(cancel: CancelContext? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line, execute body: () -> Guarantee<T>) -> Promise<T> {
    let rv = body()
    if cancel == nil && rv.cancelContext == nil {
        ErrorConditions.firstlyCancelContextMissing(file: file, function: function, line: line)
    }
    if let c = cancel, let rvc = rv.cancelContext {
        c.append(context: rvc)
    }

    let rp = Promise<T>(rv)
    rp.cancelContext = cancel ?? rv.cancelContext ?? CancelContext()
    return rp
}
