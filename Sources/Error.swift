//
//  Error.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 4/28/18.
//

import PromiseKit

public class PromiseCancelledError: CancellableError, CustomDebugStringConvertible {
    public init(file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        let fileBasename = URL(fileURLWithPath: "\(file)").lastPathComponent
        debugDescription = "'\(type(of: self)) at \(fileBasename) \(function):\(line)'"
    }
    
    public var isCancelled: Bool {
        return true
    }
    
    public var debugDescription: String
}

extension PromiseCancelledError: LocalizedError {
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
    public var optionalDescription: Any {
        switch self {
        case .none:
            return "nil"
        case let .some(value):
            return value
        }
    }
}
