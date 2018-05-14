//
//  Error.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//

import PromiseKit

public class PromiseCancelledError: CancellableError, CustomStringConvertible {
    init(file: String, function: String, line: UInt) {
        let fileBasename = URL(fileURLWithPath: file).lastPathComponent
        description = "(type(of: self)) at \(fileBasename) \(function):\(line)"
    }
    
    public var isCancelled: Bool {
        get {
            return true
        }
    }
    
    public var description: String
}

class ErrorConditions {
    enum Severity {
        case warning, error
    }

    static func cancelContextMissing(className: String, functionName: String, severity: Severity = .error, file: StaticString, function: StaticString, line: UInt) {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        let message = """
        \(className).\(functionName): cancel context is missing in cancel chain at \(fileBasename) \(function):\(line).
        Specify a cancel context in '\(functionName)' if the calling promise does not have one, for example:
        
        \(className.lowercased())WithoutContext.\(functionName)(cancel: context) { value in
            // body
        }
        
        """
        switch severity {
        case .warning:
            print("*** WARNING *** \(message)")
        case .error:
            assert(false, message, file: file, line: line)
            print("*** ERROR *** \(message)")
        }
    }

    static func firstlyCancelContextMissing(severity: Severity = .error, file: StaticString, function: StaticString, line: UInt) {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        let message = """
        firstlyCC: cancel context is missing at \(fileBasename) \(function):\(line).
        Specify a cancel context in 'firstlyCC' if the returned promise does not have one, for example:
        
        firstlyCC(cancel: context) { value in
            return promiseWithoutContext()
        }
        
        """
        switch severity {
        case .warning:
            print("*** WARNING *** \(message)")
        case .error:
            assert(false, message, file: file, line: line)
            print("*** ERROR *** \(message)")
        }
    }
}
