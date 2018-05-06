# CancellablePromiseKit
![badge-pod] ![badge-languages] ![badge-pms] ![badge-platforms] 

---

CancellablePromiseKit provides clear and concise cancellation extensions for [PromiseKit]

PromiseKit includes basic support for cancellation. CancellablePromiseKit extends this to make cancelling promises straightforward.

This README has the same structure as the PromiseKit README, with cancellation added to the sample code blocks:

```swift
UIApplication.shared.isNetworkActivityIndicatorVisible = true

let context = CancelContext()
let fetchImage = URLSession.shared.dataTask(.promise, with: url, cancel: context).compactMap{ UIImage(data: $0.data) }
let fetchLocation = CLLocationManager.requestLocation(cancel: context).lastValue

firstly {
    when(fulfilled: fetchImage, fetchLocation)
}.done { image, location in
    self.imageView.image = image
    self.label.text = "\(location)"
}.ensure {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
}.catch(policy: .allErrors) { error in
    // Will be invoked with a PromiseCancelledError when cancel is called on the context.
    // Use the default policy of .allErrorsExceptCancellation to ignore cancellation errors.
    self.show(UIAlertController(for: error), sender: self)
}

//…

// Cancel all tasks in the context and fail all promises with PromiseCancelledError
context.cancel()
```

# Quick Start

In your [Podfile]:

```ruby
use_frameworks!

target "Change Me!" do
  pod "PromiseKit", "~> 6.0"
  pod "CancellablePromiseKit", "~> 1.0"
end
```

CancellablePromiseKit has the same platform and XCode support as PromiseKit

# Documentation -- TBD

* Handbook
  * [Getting Started](Documentation/GettingStarted.md)
  * [Promises: Common Patterns](Documentation/CommonPatterns.md)
  * [Frequently Asked Questions](Documentation/FAQ.md)
* Manual
  * [Installation Guide](Documentation/Installation.md)
  * [Troubleshooting](Documentation/Troubleshooting.md) (eg. solutions to common compile errors)
  * [Appendix](Documentation/Appendix.md)

If you are looking for a function’s documentation, then please note
[our sources](Sources/) are thoroughly documented.

# Extensions

Cancellable extensions are provided for PromiseKit extensions where the underlying asynchronous tasks support cancellation.

The default CocoaPod provides CancellablePromises and the extension for Foundation. The other extensions are available by specifying additional subspecs in your `Podfile`,
eg:

```ruby
pod "CancellablePromiseKit/MapKit"
# MKDirections().calculate(cancel: context).then { /*…*/ }

pod "CancellablePromiseKit/CoreLocation"
# CLLocationManager.requestLocation(cancel: context).then { /*…*/ }
```

As with PromiseKit, all extensions are separate repositories.  Here is a complete list of extensions that support cancellation, linked to their github repositories:

[Alamofire]     (http://github.com/dougzilla32/CancellablePromiseKit-Alamofire)  
[Bolts]         (http://github.com/dougzilla32/CancellablePromiseKit-Bolts)  
[Cloudkit]      (http://github.com/dougzilla32/CancellablePromiseKit-CloudKit)  
[CoreLocation]  (http://github.com/dougzilla32/CancellablePromiseKit-CoreLocation)  
[Foundation]    [Foundation]  
[MapKit]        (http://github.com/dougzilla32/CancellablePromiseKit-MapKit)  
[OMGHTTPURLRQ]  [OMGHTTPURLRQ]  
[StoreKit]      (http://github.com/dougzilla32/CancellablePromiseKit-StoreKit)  
[WatchConnectivity](http://github.com/dougzilla32/CancellablePromiseKit-WatchConnectivity)  

## I don't want the extensions!

As with PromiseKit, extensions are optional:

```ruby
pod "CancellablePromiseKit/CorePromise", "~> 1.0"
```

> *Note* Carthage installations come with no extensions by default.

## Choose Your Networking Library

All the networking library extensions supported by PromiseKit are now simple to cancel!

[Alamofire]:

```swift
// pod 'CancellablePromiseKit/Alamofire'
// # https://github.com/dougzilla32/CancellablePromiseKit-Alamofire

let context = CancelContext()
firstly {
    Alamofire
        .request("http://example.com", method: .post, parameters: params)
        .responseDecodable(Foo.self, cancel: context)
}.done { foo in
    //…
}.catch { error in
    //…
}

//…

context.cancel()
```

[OMGHTTPURLRQ]:

```swift
// pod 'CancellablePromiseKit/OMGHTTPURLRQ'
// # https://github.com/dougzilla32/CancellablePromiseKit-OMGHTTPURLRQ

let context = CancelContext()
firstly {
    URLSession.shared.POST("http://example.com", JSON: params, cancel: context)
}.map {
    try JSONDecoder().decoder(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}

//…

context.cancel()
```

And (of course) plain `URLSession` from [Foundation]:

```swift
// pod 'CancellablePromiseKit/Foundation'
// # https://github.com/dougzilla32/CancellablePromiseKit-Foundation

let context = CancelContext()
firstly {
    URLSession.shared.dataTask(.promise, with: try makeUrlRequest(), cancel: context)
}.map {
    try JSONDecoder().decode(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}

//…

context.cancel()


func makeUrlRequest() throws -> URLRequest {
    var rq = URLRequest(url: url)
    rq.httpMethod = "POST"
    rq.addValue("application/json", forHTTPHeaderField: "Content-Type")
    rq.addValue("application/json", forHTTPHeaderField: "Accept")
    rq.httpBody = try JSONSerialization.jsonData(with: obj)
    return rq
}
```

[badge-pod]: https://img.shields.io/cocoapods/v/CancellablePromiseKit.svg?label=version
[badge-pms]: https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg
[badge-languages]: https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-orange.svg
[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20Linux-lightgrey.svg
[badge-mit]: https://img.shields.io/badge/license-MIT-blue.svg
[PromiseKit]: https://github.com/mxcl/PromiseKit
[CancellablePromiseKit]: https://github.com/dougzilla32/CancellablePromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancellablePromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancellablePromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancellablePromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
