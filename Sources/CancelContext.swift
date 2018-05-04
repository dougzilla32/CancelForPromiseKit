//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

public class CancelContext {
    private var cancelFunctions = [(String, String, Int) -> Void]()
    
    fileprivate init() { }
    
    public static func makeContext() -> CancelMode {
        return CancelMode.context(CancelContext())
    }
    
    func add(cancel: @escaping (String, String, Int) -> Void) {
        cancelFunctions.append(cancel)
    }
    
    public func cancelAll(file: String = #file, function: String = #function, line: Int = #line) {
        for cancel in cancelFunctions {
            cancel(file, function, line)
        }
    }
}
