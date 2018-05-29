//
//  CustomStringConvertible.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/18/18.
//

import PromiseKit

public protocol ThenableDescription: class, CustomStringConvertible {
    associatedtype U: Thenable
    
    var thenable: U? { get }
}

public class PromiseDescription<T>: ThenableDescription {
    public typealias U = Promise<T>
    
    public weak var thenable: Promise<T>? {
        return promise
    }
    
    weak var promise: Promise<T>?
    
    public init(_ promise: Promise<T>) {
        self.promise = promise
    }

    public init(_ promise: CancellablePromise<T>) {
        self.promise = promise.promise
    }
    
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

public class GuaranteeDescription<T>: ThenableDescription {
    public typealias U = Guarantee<T>
    
    public weak var thenable: Guarantee<T>? {
        return guarantee
    }
    
    weak var guarantee: Guarantee<T>?
    
    public init(_ guarantee: Guarantee<T>) {
        self.guarantee = guarantee
    }

    public init(_ guarantee: CancellableGuarantee<T>) {
        self.guarantee = guarantee.guarantee
    }
    
    public var description: String {
        return guarantee?.description ?? ""
    }
}
