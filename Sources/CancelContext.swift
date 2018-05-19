//
//  CancelContext.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/3/18.
//

import PromiseKit

class CancelItem: Hashable, CustomStringConvertible {
    lazy var hashValue: Int = {
        return ObjectIdentifier(self).hashValue
    }()
    
    static func == (lhs: CancelItem, rhs: CancelItem) -> Bool {
        return lhs === rhs
    }
    
    let task: CancellableTask?
    var reject: ((Error) -> Void)?
    weak var context: CancelContext?
    var cancelAttempted = false
    
    init(task: CancellableTask?, reject: ((Error) -> Void)?, description: CustomStringConvertibleClass? = nil) {
        self.task = task
        self.reject = reject
        self.descriptionClass = description
    }
    
    init(context: CancelContext, description: CustomStringConvertibleClass? = nil) {
        self.task = nil
        self.context = context
        self.descriptionClass = description
    }
    
    func cancel(error: Error, visited: Set<CancelContext>? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelAttempted = true

        task?.cancel()
        reject?(error)
        reject = nil

        if var v = visited, let c = context {
            if !v.contains(c) {
                v.insert(c)
                c.cancel(error: error, visited: v, file: file, function: function, line: line)
            }
        }
    }
    
    var isCancelled: Bool {
        return task?.isCancelled ?? cancelAttempted
    }

    // MARK: CanceItem description
    
    var descriptionOfClass: String?
    
    public var descriptionClass: CustomStringConvertibleClass? {
        didSet {
            self.descriptionOfClass = descriptionClass != nil ? descriptionClass!.description : nil
        }
    }
    
    public var description: String {
        var rv = rawPointerDescription(obj: self)
        if let desc = descriptionClass?.description, desc != "" {
            rv += "  \(desc) "
        } else if let desc = descriptionOfClass, desc != "" {
            rv += " [\(desc)]"
        }
        
        if let t = task {
            rv += " task=\(t)"
        }
        if let r = reject {
            rv += " reject=\(r)"
        }
        return rv
    }
}

public class CancelContext: Hashable, CustomStringConvertible {
    public lazy var hashValue: Int = {
        return ObjectIdentifier(self).hashValue
    }()
    
    public static func == (lhs: CancelContext, rhs: CancelContext) -> Bool {
        return lhs === rhs
    }
    
    private var cancelItemList = [CancelItem]()
    private var cancelItemSet = Set<CancelItem>()
    
    public var cancelAttempted: Bool {
        return cancelledError != nil
    }
    
    public private(set) var cancelledError: Error?
    
    public func append(task: CancellableTask?, reject: ((Error) -> Void)?, description: CustomStringConvertibleClass? = nil) {
        let item = CancelItem(task: task, reject: reject, description: description)
        if let error = cancelledError {
            item.cancel(error: error)
        }
        cancelItemList.append(item)
        cancelItemSet.insert(item)
    }
    
    func append(context childContext: CancelContext, description: CustomStringConvertibleClass? = nil) {
        guard childContext !== self else {
            return
        }
        
        if let parentError = cancelledError {
            if !childContext.cancelAttempted {
                childContext.cancel(error: parentError)
            }
        } else if let childError = childContext.cancelledError {
            if !cancelAttempted {
                cancel(error: childError)
            }
        }
        
        let item = CancelItem(context: childContext, description: description)
        cancelItemList.append(item)
        cancelItemSet.insert(item)
    }
    
    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.cancel(error: error, visited: Set<CancelContext>(), file: file, function: function, line: line)
    }
    
    func cancel(error: Error? = nil, visited: Set<CancelContext>, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        cancelledError = error ?? PromiseCancelledError(file: file, function: function, line: line)
        for item in cancelItemList {
            item.cancel(error: cancelledError!, visited: visited, file: file, function: function, line: line)
        }
    }

    public var isCancelled: Bool {
        for item in cancelItemList where !item.isCancelled {
            return false
        }
        return true
    }
    
    // MARK: CancelContext description

    public init(description: CustomStringConvertibleClass? = nil) {
        self.descriptionClass = description
    }

    var descriptionOfClass: String?
    
    public var descriptionClass: CustomStringConvertibleClass? {
        didSet {
            self.descriptionOfClass = descriptionClass != nil ? descriptionClass!.description : nil
        }
    }
    
    public var description: String {
        var rv = rawPointerDescription(obj: self)
        if let desc = descriptionClass?.description, desc != "" {
            rv += "  \(desc) "
        } else if let desc = descriptionOfClass, desc != "" {
            rv += " [\(desc)]"
        }
        return rv
    }
}
