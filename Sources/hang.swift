import PromiseKit

public func hangCC<T>(_ promise: Promise<T>) throws -> T {
    return try hang(promise)
}
