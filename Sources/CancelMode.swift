//
//  CancelMode.swift
//  CancellablePromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

public enum CancelMode {
    case enabled
    case disabled
    case context(CancelContext)
    
    public func cancelAll(file: String = #file, function: String = #function, line: Int = #line) {
        switch self {
        case .context(let context):
            context.cancelAll(file: file, function: function, line: line)
        case .enabled, .disabled:
            break
        }
    }
}
