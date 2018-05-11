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
        if cancel != nil && rv.cancelContext == nil {
            let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
            let message = """
            firstlyCC: 'body' returned a value that has no cancel context at \(fileBasename) \(function):\(line). Specifiy a cancel context in 'firstlyCC' if the returned promise does not have one, for example:
                firstlyCC(cancel: context) {
                    return MyPromiseWithoutContext()
                }
            
            """
            assert(false, message, file: file, line: line)
            NSLog("*** WARNING *** \(message)")
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
    if cancel != nil && rv.cancelContext == nil {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        let message = """
        firstlyCC: 'body' returned a value that has no cancel context at \(fileBasename) \(function):\(line). Specifiy a cancel context in 'firstlyCC' if the returned promise does not have one, for example:
            firstlyCC(cancel: context) {
                return MyPromiseWithoutContext()
            }
        
        """
        assert(false, message, file: file, line: line)
        NSLog("*** WARNING *** \(message)")
    }
    if let c = cancel, let rvc = rv.cancelContext {
        c.append(context: rvc)
    }
    let rp = Promise<T>(rv)
    rp.cancelContext = cancel ?? rv.cancelContext ?? CancelContext()
    return rp
}
