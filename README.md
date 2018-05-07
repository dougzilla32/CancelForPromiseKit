# CancelForPromiseKit
![badge-pod] ![badge-languages] ![badge-pms] ![badge-platforms] ![badge-mit]

---

CancelForPromiseKit provides clear and concise cancellation extensions for [PromiseKit]

While PromiseKit includes basic support for cancellation, CancelForPromiseKit extends this to make cancelling promises and their associated tasks simple and straightforward.

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
  pod "CancelForPromiseKit", "~> 1.0"
end
```

CancelForPromiseKit has the same platform and XCode support as PromiseKit

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

The default CocoaPod provides the core cancellable promises and the extension for Foundation. The other extensions are available by specifying additional subspecs in your `Podfile`,
eg:

```ruby
pod "CancelForPromiseKit/MapKit"
# MKDirections().calculate(cancel: context).then { /*…*/ }

pod "CancelForPromiseKit/CoreLocation"
# CLLocationManager.requestLocation(cancel: context).then { /*…*/ }
```

As with PromiseKit, all extensions are separate repositories.  Here is a complete list of extensions that support cancellation, linked to their github repositories:

[Alamofire][Alamofire]  
[Bolts](http://github.com/dougzilla32/CancelForPromiseKit-Bolts)  
[Cloudkit](http://github.com/dougzilla32/CancelForPromiseKit-CloudKit)  
[CoreLocation](http://github.com/dougzilla32/CancelForPromiseKit-CoreLocation)  
[Foundation][Foundation]  
[MapKit](http://github.com/dougzilla32/CancelForPromiseKit-MapKit)  
[OMGHTTPURLRQ][OMGHTTPURLRQ]  
[StoreKit](http://github.com/dougzilla32/CancelForPromiseKit-StoreKit)  
[WatchConnectivity](http://github.com/dougzilla32/CancelForPromiseKit-WatchConnectivity)  

## I don't want the extensions!

As with PromiseKit, extensions are optional:

```ruby
pod "CancelForPromiseKit/CorePromise", "~> 1.0"
```

> *Note* Carthage installations come with no extensions by default.

## Choose Your Networking Library

All the networking library extensions supported by PromiseKit are now simple to cancel!

[Alamofire]:

```swift
// pod 'CancelForPromiseKit/Alamofire'
// # https://github.com/dougzilla32/CancelForPromiseKit-Alamofire

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
// pod 'CancelForPromiseKit/OMGHTTPURLRQ'
// # https://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ

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
// pod 'CancelForPromiseKit/Foundation'
// # https://github.com/dougzilla32/CancelForPromiseKit-Foundation

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

[badge-pod]: https://img.shields.io/cocoapods/v/CancelForPromiseKit.svg?label=version
[badge-pms]: https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg
[badge-languages]: https://img.shields.io/badge/languages-Swift-orange.svg
[badge-platforms]: https://img.shields.io/cocoapods/p/CancelForPromiseKit.svg
[badge-mit]: https://img.shields.io/badge/license-MIT-blue.svg
[PromiseKit]: https://github.com/mxcl/PromiseKit
[CancelForPromiseKit]: https://github.com/dougzilla32/CancelForPromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancelForPromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancelForPromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
