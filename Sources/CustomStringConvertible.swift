//
//  CustomStringConvertible.swift
//  CancelForPromiseKit
//
//  Created by Doug on 5/18/18.
//

import PromiseKit

public protocol CustomStringConvertibleClass: class, CustomStringConvertible { }

public class PromiseDescription<T>: CustomStringConvertibleClass {
    weak var promise: Promise<T>?
    
    public init(_ promise: Promise<T>) {
        self.promise = promise
    }

    public var description: String {
        return promise?.description ?? "nil<Promise>"
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

public class GuaranteeDescription<T>: CustomStringConvertibleClass {
    weak var guarantee: Guarantee<T>?
    
    public init(_ guarantee: Guarantee<T>) {
        self.guarantee = guarantee
    }

    public var description: String {
        return guarantee?.description ?? "nil<Guarantee>"
    }
}
