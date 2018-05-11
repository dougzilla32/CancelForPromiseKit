import PlaygroundSupport

// Is this erroring? If so open the `.xcodeproj` and build the
// framework for a macOS target (usually labeled: “My Mac”).
// Then select `CancelForPromiseKit.playground` from inside Xcode.
import PromiseKit
import CancelForPromiseKit

func promise3(cancel: CancelContext) -> Promise<Int> {
    return afterCC(.seconds(1), cancel: cancel).map{ 3 }
}

let context = CancelContext()
firstlyCC(cancel: context) {
    Promise.valueCC(1)
}.mapCC { _ in
    2
}.thenCC { _ in
    promise3(cancel: context)
}.doneCC {
    print($0)  // => 3
}.ensureCC {
    PlaygroundPage.current.finishExecution()
}.catchCC(policy: .allErrors) { error in
    // only happens for errors
    print(error)
}

PlaygroundPage.current.needsIndefiniteExecution = true

context.cancel()
