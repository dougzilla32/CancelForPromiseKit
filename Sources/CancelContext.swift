//
//  CancelContext.swift
//  CancellablePromiseKit
//
//  Created by Doug on 5/3/18.
//

import PromiseKit

class CancelItem: Hashable, CustomDebugStringConvertible {
    lazy var hashValue: Int = {
        return ObjectIdentifier(self).hashValue
    }()
    
    static func == (lhs: CancelItem, rhs: CancelItem) -> Bool {
        return lhs === rhs
    }
    
    let task: CancellableTask?
    var reject: ((Error) -> Void)?
    var context: CancelContext?
    var cancelAttempted = false
    
    init(task: CancellableTask?, reject: ((Error) -> Void)?) {
        self.task = task
        self.reject = reject
    }
    
    init(context: CancelContext) {
        self.task = nil
        self.reject = nil
        self.context = context
    }
    
    public var debugDescription: String {
        return rawPointerDescription(obj: self)
    }
    
    func cancel(error: Error) {
        task?.cancel()
        reject?(error)
        reject = nil
        context?.cancel()
        context = nil
        cancelAttempted = true
    }
    
    var isCancelled: Bool {
        return context?.isCancelled ?? task?.isCancelled ?? cancelAttempted
    }
}

extension NSMapTable where KeyType == CancelContext, ObjectType == CancelContext {
    subscript(key: KeyType) -> ObjectType? {
        get {
            return object(forKey: key)
        }
        
        set {
            if newValue != nil {
                setObject(newValue, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }
}

public class CancelContext: Hashable, CustomDebugStringConvertible {
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    public static func == (lhs: CancelContext, rhs: CancelContext) -> Bool {
        return lhs === rhs
    }
    
    private var cancelItemList = [CancelItem]()
    private var cancelItemSet = Set<CancelItem>()
    private var inheritedContexts: NSMapTable<CancelContext, CancelContext>!
    private weak var rootContext: CancelContext?

    public init() { }
    
    public var debugDescription: String {
        return rawPointerDescription(obj: self)
    }

    public var cancelAttempted: Bool {
        return cancelledError != nil
    }
    
    public private(set) var cancelledError: Error?
    
    public func append(task: CancellableTask?, reject: ((Error) -> Void)?) {
        let item = CancelItem(task: task, reject: reject)
        if let error = cancelledError {
            item.cancel(error: error)
        }
        cancelItemList.append(item)
        cancelItemSet.insert(item)
    }
    
    func append(context childContext: CancelContext) {
        guard childContext !== self else {
            return
        }
        
        // If this context is rooted somewhere else, then add that root here instead
        var childContext = childContext
        if let childRoot = childContext.rootContext {
            childContext = childRoot
        }
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
        
        let item = CancelItem(context: childContext)
        cancelItemList.append(item)
        cancelItemSet.insert(item)
        
        // Find/create the root inheritedContexts maptable
        let rootInheritedContexts: NSMapTable<CancelContext, CancelContext>
        let root: CancelContext
        if rootContext != nil {
            root = rootContext!
            rootInheritedContexts = rootContext!.inheritedContexts
        } else {
            root = self
            if self.inheritedContexts == nil {
                self.inheritedContexts = NSMapTable.weakToWeakObjects()
            }
            rootInheritedContexts = self.inheritedContexts
        }
        
        // Merge the child context table into our root context table, removing duplicate references in the child as needed
        if let childInheritedContexts = childContext.inheritedContexts {
            childContext.inheritedContexts = nil
            for case let child as CancelContext in childInheritedContexts.keyEnumerator() {
                let parent = childInheritedContexts.object(forKey: child)
                if rootInheritedContexts.object(forKey: child) != nil {
                    // Remove the other reference
                    print("remove other reference")
                    parent?.remove(context: child)
                } else {
                    // Add the other reference to the root table
                    print("port other reference")
                    rootInheritedContexts.setObject(parent, forKey: child)
                    child.rootContext = root
                }
            }
            childInheritedContexts.removeAllObjects()
        }

        rootInheritedContexts.setObject(self, forKey: childContext)
    }
    
    func remove(context: CancelContext) {
        cancelItemList = cancelItemList.filter { $0.context !== context }
        // Can improve performance of the remove from Set operation, should be O(1) not O(n)
        cancelItemSet = Set(cancelItemSet.filter { $0.context != context })
    }
    
    public func cancel(error: Error? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        cancelledError = error ?? PromiseCancelledError(file: file, function: function, line: line)
        for item in cancelItemList {
            item.cancel(error: cancelledError!)
        }
    }

    public var isCancelled: Bool {
        for item in cancelItemList where !item.isCancelled {
            return false
        }
        return true
    }

    public func done(file: String = #file, function: String = #function, line: UInt = #line) {
        cancelItemList.removeAll()
        cancelItemSet.removeAll()
    }
}
