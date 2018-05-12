//
//  Error.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//

import PromiseKit

public class PromiseCancelledError: CancellableError, CustomStringConvertible {
    public private(set) var file: String
    public private(set) var function: String
    public private(set) var line: UInt
    
    init(file: String, function: String, line: UInt) {
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
    }
    
    public var isCancelled: Bool {
        get {
            return true
        }
    }
    
    public var description: String {
        return "PromiseCancelledError at \(file) \(function):\(line)"
    }
}

class ErrorConditions {
    static func cancelContextMissing(className: String, functionName: String, file: StaticString, function: StaticString, line: UInt) {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        let message = """
        \(className).\(functionName): cancel context is missing in cancel chain at \(fileBasename) \(function):\(line).
        Specify a cancel context in '\(functionName)' if the calling promise does not have one, for example:
        
        \(className.lowercased())WithoutContext.\(functionName)(cancel: context) { value in
            // body
        }
        
        """
        assert(false, message, file: file, line: line)
        print("*** ERROR *** \(message)")
    }
}
