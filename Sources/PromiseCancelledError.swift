//
//  PromiseCancelledError.swift
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
        self.file = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        self.function = function
        self.line = line
    }
    
    public var isCancelled: Bool {
        get {
            return true
        }
    }
    
    public var description: String {
        return "PromiseCancelledError at \(file).\(function):\(line)"
    }
}
