//
//  Error.swift
//  CancellablePromiseKit
//
//  Created by Doug on 4/28/18.
//  Copyright © 2018 Doug Stein. All rights reserved.
//

import PromiseKit

// MARK: Cancellable error

class PromiseCancelledError: CancellableError {
    var isCancelled: Bool {
        get {
            return true
        }
    }
}
