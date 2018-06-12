//
//  CancelContext.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

import PromiseKit

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
    
    // Atomic access to cancelledError
    let cancelledErrorSemaphore = DispatchSemaphore(value: 1)
    private var internalCancelledError: Error?
    public private(set) var cancelledError: Error? {
        get {
            let error: Error?
            cancelledErrorSemaphore.wait()
            error = internalCancelledError
            cancelledErrorSemaphore.signal()
            return error
        }
        
        set {
            cancelledErrorSemaphore.wait()
            internalCancelledError = newValue
            cancelledErrorSemaphore.signal()
        }
    }
    
    init(description: CustomStringConvertible? = nil) {
        self.descriptionCSC = description
    }
    
    var cachedDescription: String?
    
    var descriptionCSC: CustomStringConvertible? {
        didSet {
#if DEBUG
            self.cachedDescription = descriptionCSC?.description
#endif
        }
    }
    
    public var description: String {
        var rv = rawPointerDescription(obj: self)
        if let desc = descriptionCSC?.description, desc != "" {
            rv += "  \(desc) "
        } else if let desc = cachedDescription, desc != "" {
            rv += " [\(desc)]"
        }
        return rv
    }

    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.cancel(error: error, visited: Set<CancelContext>(), file: file, function: function, line: line)
    }
    
    func cancel(error: Error? = nil, visited: Set<CancelContext>, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        var error = error
        if error == nil {
            error = PromiseCancelledError(file: file, function: function, line: line)
        }

        cancelledError = error
        
        for item in cancelItemList {
            item.cancel(error: error!, visited: visited, file: file, function: function, line: line)
        }
    }
    
    public var isCancelled: Bool {
        for item in cancelItemList where !item.isCancelled {
            return false
        }
        return true
    }
    
    func append<Z: CancellableThenable>(task: CancellableTask?, reject: ((Error) -> Void)?, thenable: Z) {
        if task == nil && reject == nil {
            return
        }
        let item = CancelItem(task: task, reject: reject, thenable: thenable.thenable)
        if let error = cancelledError {
            item.cancel(error: error)
        }
        cancelItemList.append(item)
        cancelItemSet.insert(item)
        thenable.cancelItems.append(item)
    }
    
    func append<Z: CancellableThenable>(context childContext: CancelContext, thenable: Z) {
        if validateContext(context: childContext) {
            let item = CancelItem(context: childContext, thenable: thenable.thenable)
            cancelItemList.append(item)
            cancelItemSet.insert(item)
            thenable.cancelItems.append(item)
        }
    }
    
    func append<Z: ThenableDescription>(context childContext: CancelContext, description: Z, cancelItems: CancelItemList) {
        if validateContext(context: childContext) {
            let item = CancelItem(context: childContext, description: description)
            cancelItemList.append(item)
            cancelItemSet.insert(item)
            cancelItems.append(item)
        }
    }
    
    private func validateContext(context childContext: CancelContext) -> Bool {
        guard childContext !== self else {
            return false
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
        
        return true
    }
    
    func recover() {
        cancelledError = nil
    }
    
    func removeItems(_ list: CancelItemList, clearList: Bool) {
        guard list.items.count != 0 else {
            return
        }
        
        defer {
            if clearList {
                list.removeAll()
            }
        }
        
        var currentIndex = 1
        // The 'list' parameter should match a block of items in the cancelItemList, remove them from the cancelItemList
        // in one operation for efficiency
        if cancelItemSet.remove(list.items[0]) != nil {
            let removeIndex = cancelItemList.index(of: list.items[0])!
            while currentIndex < list.items.count {
                let item = list.items[currentIndex]
                if item != cancelItemList[removeIndex + currentIndex] {
                    break
                }
                cancelItemSet.remove(item)
                currentIndex += 1
            }
            cancelItemList.removeSubrange(removeIndex..<(removeIndex+currentIndex))
        }
        
        // Remove whatever falls outside of the block
        while currentIndex < list.items.count {
            let item = list.items[currentIndex]
            if cancelItemSet.remove(item) != nil {
                cancelItemList.remove(at: cancelItemList.index(of: item)!)
            }
            currentIndex += 1
        }
    }
}

public class CancelItemList {
    fileprivate var items = [CancelItem]()
    
    init() {}
    
    func append(_ item: CancelItem) {
        items.append(item)
    }
    
    func append(contentsOf list: CancelItemList, clearList: Bool) {
        items.append(contentsOf: list.items)
        if clearList {
            list.removeAll()
        }
    }
    
    func removeAll() {
        items.removeAll()
    }
}

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
    
    init<Z: Thenable>(task: CancellableTask?, reject: ((Error) -> Void)?, thenable: Z) {
        self.task = task
        self.reject = reject
        self.descriptionCSC = CancelItem.createDescription(thenable)
    }
    
    init<Z: Thenable>(context: CancelContext, thenable: Z) {
        self.task = nil
        self.context = context
        self.descriptionCSC = CancelItem.createDescription(thenable)
    }
    
    init<Z: ThenableDescription>(context: CancelContext, description: Z) {
        self.task = nil
        self.context = context
        self.descriptionCSC = description
    }
    
    static func createDescription<Z: Thenable>(_ thenable: Z) -> CustomStringConvertible {
        if let promise = thenable as? Promise<Z.T> {
            return PromiseDescription(promise)
        } else {
            return GuaranteeDescription(thenable as! Guarantee<Z.T>)
        }
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
    
    var cachedDescription: String?
    
    var descriptionCSC: CustomStringConvertible {
        didSet {
#if DEBUG
            self.cachedDescription = descriptionCSC.description
#endif
        }
    }
    
    var description: String {
        var rv = rawPointerDescription(obj: self)
        let desc = descriptionCSC.description
        if desc != "" {
            rv += "  \(desc) "
        } else if let desc = cachedDescription, desc != "" {
            rv += " [\(desc)]"
        }
        
        if let t = task {
            rv += " task=\(t)"
        }
        if let r = reject {
            rv += " reject=\(r)"
        }
        if let c = context {
            rv += " context=\(c)"
        }
        return rv
    }
}
