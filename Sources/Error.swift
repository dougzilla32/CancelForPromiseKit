//
//  Error.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 4/28/18.
//

import Foundation
import PromiseKit

/**
 PromiseCancelledError is thrown when `cancel` is called on a cancellable promise chain.  The promise `catch` will
 handle this error if the policy `.allErrors` is specified.
 */
public class PromiseCancelledError: CancellableError, CustomDebugStringConvertible {
    /// create a new `PromiseCancelledError`
    public init(file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        debugDescription = "'\(type(of: self)) at \(fileBasename) \(function):\(line)'"
    }
    
    /// returns true if this Error represents a cancelled condition
    public var isCancelled: Bool {
        return true
    }
    
    /// A textual representation of this instance, suitable for debugging.
    public var debugDescription: String
}

extension PromiseCancelledError: LocalizedError {
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        return debugDescription
    }
}

func rawPointerDescription(obj: AnyObject) -> String {
    let id = ObjectIdentifier(obj)
    let idDesc = id.debugDescription
    let offsetString = "\(type(of: id))"
#if swift(>=3.2)
    let index = idDesc.index(idDesc.startIndex, offsetBy: offsetString.count)
    let pointerString = idDesc[index...]
#else
    let index = idDesc.index(idDesc.startIndex, offsetBy: offsetString.characters.count)
    let pointerString = idDesc.substring(from: index)
#endif
    return "\(type(of: obj))\(pointerString)"
}

extension Optional {
    /// A textual representation of this instance.
    public var optionalDescription: Any {
        switch self {
        case .none:
            return "nil"
        case let .some(value):
            return value
        }
    }
}
