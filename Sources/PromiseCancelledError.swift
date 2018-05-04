//
//  Error.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import PromiseKit

// MARK: Cancellable error

public class PromiseCancelledError: CancellableError, CustomStringConvertible {
    public private(set) var file: String
    public private(set) var function: String
    public private(set) var line: Int
    
    init(file: String, function: String, line: Int) {
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
