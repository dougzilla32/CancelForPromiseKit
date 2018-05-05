//
//  CancellableTask.swift
//  CancellablePromiseKit
//
//  Created by Doug Stein on 5/3/18.
//

import Foundation

public protocol CancellableTask {
    func cancel()
    
    var isCancelled: Bool { get }
}

extension DispatchWorkItem: CancellableTask { }
