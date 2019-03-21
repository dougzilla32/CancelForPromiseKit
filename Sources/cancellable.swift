/// Returns a cancellable version of the given Thenable.
public func cancellable<U: Thenable>(_ thenable: U, cancelContext: CancelContext? = nil) -> CancellablePromise<U.T> {
    return CancellablePromise(thenable, cancelContext: cancelContext)
}
