# CancelForPromiseKit
![badge-pod] ![badge-languages] ![badge-pms] ![badge-platforms] ![badge-mit] [![Build Status](https://travis-ci.org/dougzilla32/CancelForPromiseKit.svg?branch=master)](https://travis-ci.org/dougzilla32/CancelForPromiseKit)

---

CancelForPromiseKit provides clear and concise cancellation abilities for [PromiseKit] and for the [PromiseKit Extensions].  While PromiseKit includes basic support for cancellation, CancelForPromiseKit extends this to make cancelling promises and their associated tasks simple and straightforward.

The goals of this project are as follows:

* **A streamlined way to cancel a promise chain, which rejects all associated promises and cancels all associated tasks. For example:**

```swift
let promise = firstly {
    loginCC() // Use 'CC' (a.k.a. cancel chain) methods or CancellablePromise to
              // initiate a cancellable promise chain
}.then { creds in
    fetch(avatar: creds.user)
}.done { image in
    self.imageView = image
}.catch(policy: .allErrors) { error in
    if error.isCancelled {
        // the chain has been cancelled!
    }
}
//…
promise.cancel()
```
* **Ensure that subsequent code blocks in a promise chain are _NEVER_ called after the chain has been cancelled**

* **Provide cancellable varients for all appropriate PromiseKit extensions (e.g. Foundation, CoreLocation, Alamofire)**

* **Support cancellation for all PromiseKit primitives such as 'after', 'firstly', 'when', 'race'**

* **A simple way to make new types of cancellable promises**

CancelForPromiseKit defines it's extensions as methods and functions with the 'CC' (cancel chain) suffix.

This README has the same structure as the [PromiseKit README], with cancellation added to the sample code blocks:

```swift
UIApplication.shared.isNetworkActivityIndicatorVisible = true

let fetchImage = URLSession.shared.dataTaskCC(.promise, with: url).compactMap{ UIImage(data: $0.data) }
let fetchLocation = CLLocationManager.requestLocationCC().lastValue

// Hold on to the 'CancelContext' rather than the promise chain so the
// promises can be freed up.
let context = firstly {
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
}.cancelContext

//…

// Cancel currently active tasks and reject all promises with PromiseCancelledError
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

The following functions are part of the core CancelForPromiseKit module:

	Global functions
		after(seconds:cancel:)
		after(_ interval:cancel:)
		
	Promise extensions
		value(_ value: cancel:)
		init(cancel:resolver:)
		init(cancel:task:resolver:)

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

CancelForPromiseKit provides the same extensions and functions as PromiseKit so long as the underlying asynchronous task(s) support cancellation.

The default CocoaPod provides the core cancellable promises and the extension for Foundation. The other extensions are available by specifying additional subspecs in your `Podfile`,
eg:

```ruby
pod "CancelForPromiseKit/MapKit"
# MKDirections().calculateCC().then { /*…*/ }

pod "CancelForPromiseKit/CoreLocation"
# CLLocationManager.requestLocationCC().then { /*…*/ }
```

As with PromiseKit, all extensions are separate repositories.  Here is a complete list of CancelForPromiseKit extensions listing the specific functions that support cancellation (PromiseKit extensions without any functions supporting cancellation are omitted):

[Alamofire][Alamofire]  

	Alamofire.DataRequest
		responseCC(_:queue:)
		responseDataCC(queue:)
		responseStringCC(queue:)
		responseJSONCC(queue:options:)
		responsePropertyListCC(queue:options:)
		responseDecodableCC<T>(queue::decoder:)
		responseDecodableCC<T>(_ type:queue:decoder:)

	Alamofire.DownloadRequest
		responseCC(_:queue:)
		responseDataCC(queue:)

[Bolts](http://github.com/dougzilla32/CancelForPromiseKit-Bolts)  
[Cloudkit](http://github.com/dougzilla32/CancelForPromiseKit-CloudKit)  
[CoreLocation](http://github.com/dougzilla32/CancelForPromiseKit-CoreLocation)  
[Foundation][Foundation]  

	Process
		launchCC(_:)
		
	URLSession
		dataTaskCC(_:with:)
		uploadTaskCC(_:with:from:)
		uploadTaskCC(_:with:fromFile:)
		downloadTaskCC(_:with:to:)

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

let context = firstly {
    Alamofire
        .request("http://example.com", method: .post, parameters: params)
        .responseDecodableCC(Foo.self, cancel: context)
}.done { foo in
    //…
}.catch { error in
    //…
}.cancelContext

//…

context.cancel()
```

[OMGHTTPURLRQ]:

```swift
// pod 'CancelForPromiseKit/OMGHTTPURLRQ'
// # https://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ

let context = firstly {
    URLSession.shared.POSTCC("http://example.com", JSON: params)
}.map {
    try JSONDecoder().decoder(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}.cancelContext

//…

context.cancel()
```

And (of course) plain `URLSession` from [Foundation]:

```swift
// pod 'CancelForPromiseKit/Foundation'
// # https://github.com/dougzilla32/CancelForPromiseKit-Foundation

let context = firstly {
    URLSession.shared.dataTaskCC(.promise, with: try makeUrlRequest())
}.map {
    try JSONDecoder().decode(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}.cancelContext

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
[PromiseKit Extensions]: https://github.com/PromiseKit
[PromiseKit README]: https://github.com/mxcl/PromiseKit/blob/master/README.md
[CancelForPromiseKit]: https://github.com/dougzilla32/CancelForPromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancelForPromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancelForPromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
