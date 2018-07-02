import Foundation
import PromiseKit

#if Carthage
import PMKFoundation
#else
#if swift(>=4.1)
#if canImport(PMKFoundation)
import PMKFoundation
#endif
#endif
#endif

#if !CPKCocoaPods
import CancelForPromiseKit
#endif

/**
 To import the cancellable `NSObject` category:
 
 use_frameworks!
 pod "CancelForPromiseKit/Foundation"
 
 Or cancellable `NSObject` is one of the categories imported by the umbrella pod:
 
 use_frameworks!
 pod "CancelForPromiseKit"
 
 And then in your sources:
 
 import PromiseKit
 import CancelForPromiseKit
 */
extension NSObject {
    /**
     - Returns: A promise that resolves when the provided keyPath changes, or when the promise is cancelled.
     - Warning: *Important* The promise must not outlive the object under observation.
     - SeeAlso: Apple’s KVO documentation.
     */
    public func observeCC(_: PMKNamespacer, keyPath: String) -> CancellablePromise<Any?> {
        var task: CancellableTask!
        var reject: ((Error) -> Void)!
        
        let promise = CancellablePromise<Any?> { seal in
            reject = seal.reject
            task = KVOProxy(observee: self, keyPath: keyPath, resolve: seal.fulfill)
         }
        
        promise.appendCancellableTask(task: task, reject: reject)
        return promise
    }
}

private class KVOProxy: NSObject, CancellableTask {
    var retainCycle: KVOProxy?
    let fulfill: (Any?) -> Void
    let observeeObject: NSObject
    let observeeKeyPath: String
    
    @discardableResult
    init(observee: NSObject, keyPath: String, resolve: @escaping (Any?) -> Void) {
        fulfill = resolve
        observeeObject = observee
        observeeKeyPath = keyPath
        super.init()
        observee.addObserver(self, forKeyPath: keyPath, options: NSKeyValueObservingOptions.new, context: pointer)
        retainCycle = self
    }
    
    fileprivate override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let change = change, context == pointer {
            defer { retainCycle = nil }
            fulfill(change[NSKeyValueChangeKey.newKey])
            if let object = object as? NSObject, let keyPath = keyPath {
                object.removeObserver(self, forKeyPath: keyPath)
            }
        }
    }
    
    func cancel() {
        if !isCancelled {
            observeeObject.removeObserver(self, forKeyPath: observeeKeyPath)
            isCancelled = true
        }
    }
    
    var isCancelled = false
    
    private lazy var pointer: UnsafeMutableRawPointer = {
        return Unmanaged<KVOProxy>.passUnretained(self).toOpaque()
    }()
}
