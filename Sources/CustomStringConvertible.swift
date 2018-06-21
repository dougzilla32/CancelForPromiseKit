//
//  CustomStringConvertible.swift
//  CancelForPromiseKit
//
//  Created by Doug Stein on 5/18/18.
//

import PromiseKit

/// Superclass for PromiseDescription and GuaranteeDescription
protocol ThenableDescription: class, CustomStringConvertible {
    associatedtype U: Thenable
    
    var thenable: U? { get }
}

/// Holds a weak reference to a Promise providing a description for the Promise
class PromiseDescription<T>: ThenableDescription {
    typealias U = Promise<T>
    
    weak var thenable: Promise<T>? {
        return promise
    }
    
    weak var promise: Promise<T>?
    
    init() { }
    
    init(_ promise: Promise<T>) {
        self.promise = promise
    }

    init(_ promise: CancellablePromise<T>) {
        self.promise = promise.promise
    }
    
    /// Returns the description for the Promise or an empty string if the Promise has been reclaimed.
    public var description: String {
        return promise?.description ?? ""
    }
}

extension Guarantee: CustomStringConvertible {
    /// - Returns: A description of the state of this guarantee.
    public var description: String {
        switch result {
        case nil:
            return "Guarantee(…\(T.self))"
        case .rejected(let error)?:
            return "Guarantee(\(error))"
        case .fulfilled(let value)?:
            return "Guarantee(\(value))"
        }
    }
}

/// Holds a weak reference to a Guarantee providing a description String for the Guarantee
class GuaranteeDescription<T>: ThenableDescription {
    typealias U = Guarantee<T>
    
    weak var thenable: Guarantee<T>? {
        return guarantee
    }
    
    weak var guarantee: Guarantee<T>?
    
    init(_ guarantee: Guarantee<T>) {
        self.guarantee = guarantee
    }

    init(_ guarantee: CancellableGuarantee<T>) {
        self.guarantee = guarantee.guarantee
    }
    
    /// Returns the description for the Guarantee or an empty string if the Guarantee has been reclaimed.
    public var description: String {
        return guarantee?.description ?? ""
    }
}
