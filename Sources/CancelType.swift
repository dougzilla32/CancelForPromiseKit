//
//  CancelType.swift
//  CancellablePromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

public enum CancelType {
    case enable
    case disable
    case context(CancelContext)
    
    public static func createContext() -> CancelType {
        return CancelType.context(CancelContext())
    }
    
    public func cancelAll(file: String = #file, function: String = #function, line: Int = #line) {
        switch self {
        case .context(let context):
            context.cancelAll(file: file, function: function, line: line)
        case .enable, .disable:
            break
        }
    }
}

public class CancelContext {
    private var cancelFunctions = [(String, String, Int) -> Void]()
    
    fileprivate init() { }
    
    func add(cancel: @escaping (String, String, Int) -> Void) {
        cancelFunctions.append(cancel)
    }
    
    public func cancelAll(file: String = #file, function: String = #function, line: Int = #line) {
        for cancel in cancelFunctions {
            cancel(file, function, line)
        }
    }
}
