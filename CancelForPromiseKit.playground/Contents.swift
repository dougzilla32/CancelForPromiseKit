import PlaygroundSupport

// Is this erroring? If so open the `.xcodeproj` and build the
// framework for a macOS target (usually labeled: “My Mac”).
// Then select `CancelForPromiseKit.playground` from inside Xcode.
import PromiseKit
import CancelForPromiseKit

func promise3() ->
    CancellablePromise<Int> {
    return afterCC(.seconds(1)).map{ 3 }
}

let context = firstly {
    CancellablePromise.valueCC(1)
}.map { _ in
    2
}.then { _ in
    promise3()
}.done {
    print($0)  // => 3
}.ensure {
    PlaygroundPage.current.finishExecution()
}.catch(policy: .allErrors) { error in
    // only happens for errors
    print(error)
}.cancelContext

PlaygroundPage.current.needsIndefiniteExecution = true

context.cancel()
