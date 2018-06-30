//
//  CancelContext.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

import Foundation
import PromiseKit

/**
 Keeps track of all promises in a promise chain with pending or currently running tasks, and cancels them all when `cancel` is called.
 */
public class CancelContext: Hashable, CustomStringConvertible {
    /// - See: `Hashable`
    public lazy var hashValue: Int = {
        return ObjectIdentifier(self).hashValue
    }()
    
    /// - See: `Hashable`
    public static func == (lhs: CancelContext, rhs: CancelContext) -> Bool {
        return lhs === rhs
    }
    
    // Create a barrier queue that is used as a read/write lock for the CancelContext
    //   For reads:  barrier.sync { }
    //   For writes: barrier.sync(flags: .barrier) { }
    private let barrier = DispatchQueue(label: "CancelForPromiseKit.CancelContextBarrier", attributes: .concurrent)

    private var cancelItems = [CancelItem]()
    private var cancelItemSet = Set<CancelItem>()
    
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

    /**
     Cancel all members of the promise chain and their associated asynchronous operations.
     
     - Parameter error: Specifies the cancellation error to use for the cancel operation, defaults to `nil` which will create a new `PromiseCancelledError`
     */
    public func cancel(error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.cancel(error: error, visited: Set<CancelContext>(), file: file, function: function, line: line)
    }
    
    func cancel(error: Error? = nil, visited: Set<CancelContext>, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        var error = error
        if error == nil {
            error = PromiseCancelledError(file: file, function: function, line: line)
        }

        var items: [CancelItem]!
        barrier.sync(flags: .barrier) {
            internalCancelledError = error
            items = cancelItems
        }
        
        for item in items {
            item.cancel(error: error!, visited: visited, file: file, function: function, line: line)
        }
    }
    
    /**
     True if all members of the promise chain have been successfully cancelled, false otherwise.
     */
    public var isCancelled: Bool {
        var items: [CancelItem]!
        barrier.sync {
            items = cancelItems
        }
        
        for item in items where !item.isCancelled {
            return false
        }
        return true
    }
    
    /**
     True if `cancel` has been called on the CancelContext associated with this promise, false otherwise.  `cancelAttempted` will be true if `cancel` is called on any promise in the chain.
     */
    public var cancelAttempted: Bool {
        return cancelledError != nil
    }
    
    private var internalCancelledError: Error?
    
    /**
     The cancellation error initialized when the promise is cancelled, or `nil` if not cancelled.
     */
    public private(set) var cancelledError: Error? {
        get {
            var err: Error!
            barrier.sync {
                err = internalCancelledError
            }
            return err
        }
        
        set {
            barrier.sync(flags: .barrier) {
                internalCancelledError = newValue
            }
        }
    }
    
    func append<Z: CancellableThenable>(task: CancellableTask?, reject: ((Error) -> Void)?, thenable: Z) {
        if task == nil && reject == nil {
            return
        }
        let item = CancelItem(task: task, reject: reject, thenable: thenable.thenable)

        var error: Error?
        barrier.sync(flags: .barrier) {
            error = internalCancelledError
            cancelItems.append(item)
            cancelItemSet.insert(item)
            thenable.cancelItemList.append(item)
        }

        if error != nil {
            item.cancel(error: error!)
        }
    }
    
    func append<Z: CancellableThenable>(context childContext: CancelContext, thenable: Z) {
        guard childContext !== self else {
            return
        }
        let item = CancelItem(context: childContext, thenable: thenable.thenable)

        var error: Error?
        barrier.sync(flags: .barrier) {
            error = internalCancelledError
            cancelItems.append(item)
            cancelItemSet.insert(item)
            thenable.cancelItemList.append(item)
        }

        crossCancel(childContext: childContext, parentCancelledError: error)
    }
    
    func append<Z: ThenableDescription>(context childContext: CancelContext, description: Z, thenableCancelItemList: CancelItemList) {
        guard childContext !== self else {
            return
        }
        let item = CancelItem(context: childContext, description: description)

        var error: Error?
        barrier.sync(flags: .barrier) {
            error = internalCancelledError
            cancelItems.append(item)
            cancelItemSet.insert(item)
            thenableCancelItemList.append(item)
        }

        crossCancel(childContext: childContext, parentCancelledError: error)
    }
    
    private func crossCancel(childContext: CancelContext, parentCancelledError: Error?) {
        let parentError = parentCancelledError
        let childError =  childContext.cancelledError
        
        if parentError != nil {
            if childError == nil {
                childContext.cancel(error: parentError)
            }
        } else if childError != nil {
            if parentError == nil {
                cancel(error: childError)
            }
        }
    }
    
    func recover() {
        cancelledError = nil
    }
    
    func removeItems(_ list: CancelItemList, clearList: Bool) -> Error? {
        var error: Error?
        barrier.sync(flags: .barrier) {
            error = internalCancelledError
            if error == nil && list.items.count != 0 {
                var currentIndex = 1
                // The `list` parameter should match a block of items in the cancelItemList, remove them from the cancelItemList
                // in one operation for efficiency
                if cancelItemSet.remove(list.items[0]) != nil {
                    let removeIndex = cancelItems.index(of: list.items[0])!
                    while currentIndex < list.items.count {
                        let item = list.items[currentIndex]
                        if item != cancelItems[removeIndex + currentIndex] {
                            break
                        }
                        cancelItemSet.remove(item)
                        currentIndex += 1
                    }
                    cancelItems.removeSubrange(removeIndex..<(removeIndex+currentIndex))
                }
                
                // Remove whatever falls outside of the block
                while currentIndex < list.items.count {
                    let item = list.items[currentIndex]
                    if cancelItemSet.remove(item) != nil {
                        cancelItems.remove(at: cancelItems.index(of: item)!)
                    }
                    currentIndex += 1
                }
                
                if clearList {
                    list.removeAll()
                }
            }
        }
        return error
    }
}

/// Tracks the cancel items for a CancellablePromise.  These items are removed from the associated CancelContext when the promise resolves.
public class CancelItemList {
    fileprivate var items: [CancelItem]
    
    init() {
        self.items = []
    }
    
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
