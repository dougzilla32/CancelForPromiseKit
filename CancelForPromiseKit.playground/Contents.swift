import PlaygroundSupport

// Is this erroring? If so open the `.xcodeproj` and build the
// framework for a macOS target (usually labeled: “My Mac”).
// Then select `PromiseKit.playground` from inside Xcode.
import PromiseKit

import CancelForPromiseKit

func promise3(cancel: CancelContext) -> Promise<Int> {
    return after(.seconds(1), cancel: cancel).map{ 3 }
}

let context = CancelContext()
firstly {
    Promise.value(1, cancel: context)
}.mapCC { _ in
    2
}.thenCC { _ in
    promise3(cancel: context)
}.doneCC {
    print($0)  // => 3
}.ensure {
    PlaygroundPage.current.finishExecution()
}.catch(policy: .allErrors) { error in
    // only happens for errors
    print(error)
}

PlaygroundPage.current.needsIndefiniteExecution = true

context.cancel()
