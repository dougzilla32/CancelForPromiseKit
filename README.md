# CancelForPromiseKit

[![badge-pod]](https://cocoapods.org/pods/CancelForPromiseKit) [![badge-languages]](https://developer.apple.com/swift/) [![badge-pms]](https://medium.com/xcblog/swift-dependency-management-for-ios-3bcfc4771ec0) [![badge-platforms]](https://cocoapods.org/pods/CancelForPromiseKit) [![badge-mit]](https://github.com/dougzilla32/CancelForPromiseKit/blob/master/LICENSE) [![badge-docs]][CancelForPromiseKit API Documentation] [![Build Status](https://travis-ci.org/dougzilla32/CancelForPromiseKit.svg?branch=master)](https://travis-ci.org/dougzilla32/CancelForPromiseKit)

---

API Docs: | [CancelForPromiseKit](https://dougzilla32.github.io/CancelForPromiseKit/api/) | [CPKAlamofire](https://dougzilla32.github.io/CPKAlamofire/api/) | [CPKCoreLocation](https://dougzilla32.github.io/CPKCoreLocation/api/) | [CPKFoundation](https://dougzilla32.github.io/CPKFoundation/api/) |
------------- | ------------- | ------------- |  ------------- |   ------------- | 

[CancelForPromiseKit] provides clear and concise cancellation abilities for the most excellent [PromiseKit] and [PromiseKit Extensions].  While PromiseKit includes basic support for cancellation, CancelForPromiseKit extends this to make cancelling promises and their associated tasks simple and straightforward.

For example:

<pre><code>UIApplication.shared.isNetworkActivityIndicatorVisible = true

let fetchImage = URLSession.shared.dataTask<mark><b>CC</b></mark>(.promise, with: url).compactMap{ UIImage(data: $0.data) }
let fetchLocation = CLLocationManager.requestLocation<mark><b>CC</b></mark>().lastValue

<mark><b>let context =</b></mark> firstly {
    when(fulfilled: fetchImage, fetchLocation)
}.done { image, location in
    self.imageView.image = image
    self.label.text = "\(location)"
}.ensure {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
}.catch(policy: .allErrors) { error in
    /* Will be invoked with a PromiseCancelledError when cancel is called on the context.
       Use the default policy of .allErrorsExceptCancellation to ignore cancellation errors. */
    self.show(UIAlertController(for: error), sender: self)
}<mark><b>.cancelContext</b></mark>

//…

// Cancel currently active tasks and reject all cancellable promises with PromiseCancelledError
<mark><b>context.cancel()</b></mark>

/* Note: Cancellable promises can be cancelled directly.  However by holding on to
   the <mark><b>CancelContext</b></mark> rather than a promise, each promise in the chain can be
   deallocated by ARC as it is resolved. */
</code></pre>

Note: The format for this README and for the project as a whole mirrors PromiseKit in an attempt to be readable and concise. For all code samples, the differences between PromiseKit and CancelForPromiseKit are highlighted in bold.

# Quick Start with CocoaPods

In your [Podfile]:

<pre><code>use_frameworks!

target "Change Me!" do
  pod "PromiseKit", "~> 6.0"
  pod "CancelForPromiseKit", "~> 1.0"
end
</code></pre>

CancelForPromiseKit has the same platform and Xcode support as PromiseKit

# Examples

* **Cancelling a chain**

<pre><code><mark><b>let promise =</b></mark> firstly {
    /* Methods and functions with the <mark><b>CC</b></mark> (a.k.a. cancel chain) suffix initiate a
    cancellable promise chain by returning a <mark><b>CancellablePromise</b></mark>. */
    login<mark><b>CC</b></mark>()
}.then { creds in
    /* 'fetch' in this example may return either Promise or <mark><b>CancellablePromise</b></mark> --
        If 'fetch' returns a <mark><b>CancellablePromise</b></mark> then the fetch task can be cancelled.
        If 'fetch' returns a standard Promise then the fetch task cannot be cancelled,
        however if cancel is called during the fetch then the promise chain will still be
        rejected with a PromiseCancelledError as soon as the 'fetch' task completes.
        
        Note: if 'fetch' returns a <mark><b>CancellablePromise</b></mark> then the convention is to name
        it 'fetchCC'. */
    fetch(avatar: creds.user)
}.done { image in
    self.imageView = image
}.catch(policy: .allErrors) { error in
    if <mark><b>error.isCancelled</b></mark> {
        // the chain has been cancelled!
    }
}

// …

/* '<mark><b>promise</b></mark>' here refers to the last promise in the chain.  Calling '<mark><b>cancel</b></mark>' on
   any promise in the chain cancels the entire chain.  Therefore cancelling the
   last promise in the chain cancels everything.
   
   Note: It may be desirable to hold on to the <mark><b>CancelContext</b></mark> directly rather than a
   promise so that the promise can be deallocated by ARC when it is resolved. */
<mark><b>promise.cancel()</b></mark>
</code></pre>

* **Mixing Promise and CancellablePromise to cancel some branches and not others**

In the example above: if `fetch(avatar: creds.user)` returns a standard Promise then the fetch cannot be cancelled.  However, if cancel is called in the middle of the fetch then the promise chain will still be rejected with a PromiseCancelledError once the fetch completes. The `done` block will not be called and the `catch(policy: .allErrors)` block will be called instead.

If `fetch` returns a CancellablePromise then the fetch will be cancelled when `cancel()` is invoked, and the `catch` block will be called immediately.

* **Use the 'delegate' promise**

CancellablePromise wraps a delegate Promise, which can be accessed with the `promise` property.  The above example can be modified as follows so that once 'loginCC' completes, the chain cannot be cancelled:

<pre><code><mark><b>let cancellablePromise =</b></mark> firstly {
    login<mark><b>CC</b></mark>()
}
cancellablePromise.then { creds in
    // For this example 'fetch' returns a standard Promise
    fetch(avatar: creds.user)  
    
    /* Here, by calling '<mark><b>promise</b></mark>.done' rather than 'done' the chain is converted from a
       cancellable promise chain to a standard Promise chain. In this case, calling
       'cancel' during the 'fetch' operation has no effect: */
}.<mark><b>promise</b></mark>.done { image in
    self.imageView = image
}.catch(policy: .allErrors) { error in
    if <mark><b>error.isCancelled</b></mark> {
        // the chain has been cancelled!
    }
}

// …

<mark><b>cancellablePromise.cancel()</b></mark>
</code></pre>


# Documentation

The following functions and methods are part of the core CancelForPromiseKit module.  Functions and Methods with the <b>CC</b> suffix create a new CancellablePromise,
and those without the <b>CC</b> suffix accept an existing CancellablePromise.

Here is the [Jazzy](https://github.com/realm/jazzy) generated [CancelForPromiseKit API documentation].

<pre><code>Global functions (all returning <mark><b>CancellablePromise</b></mark> unless otherwise noted)
	after<mark><b>CC</b></mark>(seconds:)
	after<mark><b>CC</b></mark>(_ interval:)

	firstly(execute body:)       // Accepts body returning <mark><b>CancellableTheanble</b></mark>
	firstly<mark><b>CC</b></mark>(execute body:)     // Accepts body returning Theanble

	hang(_ promise:)             // Accepts <mark><b>CancellablePromise</b></mark>
	
	race(_ thenables:)           // Accepts <mark><b>CancellableThenable</b></mark>
	race(_ guarantees:)          // Accepts <mark><b>CancellableGuarantee</b></mark>
	race<mark><b>CC</b></mark>(_ thenables:)         // Accepts Theanable
	race<mark><b>CC</b></mark>(_ guarantees:)        // Accepts Guarantee

	when(fulfilled thenables:)   // Accepts <mark><b>CancellableThenable</b></mark>
	when(fulfilled promiseIterator:concurrently:)   // Accepts <mark><b>CancellablePromise</b></mark>
	when<mark><b>CC</b></mark>(fulfilled thenables:) // Accepts Thenable
	when<mark><b>CC</b></mark>(fulfilled promiseIterator:concurrently:) // Accepts Promise

	// These functions return <mark><b>CancellableGuarantee</b></mark>
	when(resolved promises:)     // Accepts <mark><b>CancellablePromise</b></mark>
	when(_ guarantees:)          // Accepts <mark><b>CancellableGuarantee</b></mark>
	when(guarantees:)            // Accepts <mark><b>CancellableGuarantee</b></mark>
	when<mark><b>CC</b></mark>(resolved promises:)   // Accepts Promise
	when<mark><b>CC</b></mark>(_ guarantees:)        // Accepts Guarantee
	when<mark><b>CC</b></mark>(guarantees:)          // Accepts Guarantee


<mark><b>CancellablePromise: CancellableThenable</b></mark>
	CancellablePromise.value(_ value:)
	init(task:resolver:)
	init(task:bridge:)
	init(task:error:)
	promise                      // The delegate Promise
	result

<mark><b>CancellableGuarantee: CancellableThenable</b></mark>
	CancellableGuarantee.value(_ value:)
	init(task:resolver:)
	init(task:bridge:)
	init(task:error:)
	guarantee                    // The delegate Guarantee
	result

<mark><b>CancellableThenable</b></mark>
	thenable                     // The delegate Thenable
	cancel(error:)               // Accepts optional Error to use for cancellation
	cancelContext                // CancelContext for the cancel chain we are a member of
	isCancelled
	cancelAttempted
	cancelledError
	appendCancellableTask(task:reject:)
	appendCancelContext(from:)
	
	then(on:_ body:)             // Accepts body returning CancellableThenable or Thenable
	map(on:_ transform:)
	compactMap(on:_ transform:)
	done(on:_ body:)
	get(on:_ body:)
	asVoid()
	
	error
	isPending
	isResolved
	isFulfilled
	isRejected
	value
	
	mapValues(on:_ transform:)
	flatMapValues(on:_ transform:)
	compactMapValues(on:_ transform:)
	thenMap(on:_ transform:)     // Accepts transform returning CancellableThenable or Thenable
	thenFlatMap(on:_ transform:) // Accepts transform returning CancellableThenable or Thenable
	filterValues(on:_ isIncluded:)
	firstValue
	lastValue
	sortedValues(on:)

<mark><b>CancellableCatchable</b></mark>
	catchable                    // The delegate Catchable
	recover(on:policy:_ body:)   // Accepts body returning CancellableThenable or Thenable
	recover(on:_ body:)          // Accepts body returning Void
	ensure(on:_ body:)
	ensureThen(on:_ body:)
	finally(_ body:)
	cauterize()
</code></pre>

[//]: # "* Handbook"
[//]: # "  * [Getting Started](Documentation/GettingStarted.md)"
[//]: # "  * [Promises: Common Patterns](Documentation/CommonPatterns.md)"
[//]: # "  * [Frequently Asked Questions](Documentation/FAQ.md)"
[//]: # "* Manual"
[//]: # "  * [Installation Guide](Documentation/Installation.md)"
[//]: # "  * [Troubleshooting](Documentation/Troubleshooting.md) (eg. solutions to common compile errors)"
[//]: # "  * [Appendix](Documentation/Appendix.md)"

[//]: # "If you are looking for a function’s documentation, then please note"
[//]: # "[our sources](Sources/) are thoroughly documented."

# Extensions

CancelForPromiseKit provides the same extensions and functions as PromiseKit so long as the underlying asynchronous task(s) support cancellation.

The default CocoaPod provides the core cancellable promises and the extension for Foundation. The other extensions are available by specifying additional subspecs in your `Podfile`,
eg:

<pre><code>pod "CancelForPromiseKit/MapKit"
# MKDirections().calculate<mark><b>CC</b></mark>().then { /*…*/ }

pod "CancelForPromiseKit/CoreLocation"
# CLLocationManager.requestLocation<mark><b>CC</b></mark>().then { /*…*/ }
</code></pre>

As with PromiseKit, all extensions are separate repositories.  Here is a complete list of CancelForPromiseKit extensions listing the specific functions that support cancellation (PromiseKit extensions without any functions supporting cancellation are omitted):

[Alamofire][Alamofire]  
<pre><code>Alamofire.DataRequest
	response<mark><b>CC</b></mark>(_:queue:)
	responseData<mark><b>CC</b></mark>(queue:)
	responseString<mark><b>CC</b></mark>(queue:)
	responseJSON<mark><b>CC</b></mark>(queue:options:)
	responsePropertyList<mark><b>CC</b></mark>(queue:options:)
	responseDecodable<mark><b>CC</b></mark><T>(queue::decoder:)
	responseDecodable<mark><b>CC</b></mark><T>(_ type:queue:decoder:)

Alamofire.DownloadRequest
	response<mark><b>CC</b></mark>(_:queue:)
	responseData<mark><b>CC</b></mark>(queue:)
</code></pre>

[Bolts](http://github.com/dougzilla32/CancelForPromiseKit-Bolts)  
[Cloudkit](http://github.com/dougzilla32/CancelForPromiseKit-CloudKit)  
[CoreLocation](http://github.com/dougzilla32/CancelForPromiseKit-CoreLocation)  
[Foundation][Foundation]  

<pre><code>Process
	launch<mark><b>CC</b></mark>(_:)
		
URLSession
	dataTask<mark><b>CC</b></mark>(_:with:)
	uploadTask<mark><b>CC</b></mark>(_:with:from:)
	uploadTask<mark><b>CC</b></mark>(_:with:fromFile:)
	downloadTask<mark><b>CC</b></mark>(_:with:to:)
</code></pre>

[MapKit](http://github.com/dougzilla32/CancelForPromiseKit-MapKit)  
[OMGHTTPURLRQ][OMGHTTPURLRQ]  
[StoreKit](http://github.com/dougzilla32/CancelForPromiseKit-StoreKit)  
[WatchConnectivity](http://github.com/dougzilla32/CancelForPromiseKit-WatchConnectivity)  

## I don't want the extensions!

As with PromiseKit, extensions are optional:

<pre><code>pod "CancelForPromiseKit/CorePromise", "~> 1.0"
</code></pre>

> *Note* Carthage installations come with no extensions by default.

## Choose Your Networking Library

All the networking library extensions supported by PromiseKit are now simple to cancel!

[Alamofire]:

<pre><code>// pod 'CancelForPromiseKit/Alamofire'
// # https://github.com/dougzilla32/CancelForPromiseKit-Alamofire

<mark><b>let context =</b></mark> firstly {
    Alamofire
        .request("http://example.com", method: .post, parameters: params)
        .responseDecodable<mark><b>CC</b></mark>(Foo.self, cancel: context)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark><b>.cancelContext</b></mark>

//…

<mark><b>context.cancel()</b></mark>
</code></pre>

[OMGHTTPURLRQ]:

<pre><code>
// pod 'CancelForPromiseKit/OMGHTTPURLRQ'
// # https://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ

<mark><b>let context =</b></mark> firstly {
    URLSession.shared.POST<mark><b>CC</b></mark>("http://example.com", JSON: params)
}.map {
    try JSONDecoder().decoder(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark><b>.cancelContext</b></mark>

//…

<mark><b>context.cancel()</b></mark>
</code></pre>

And (of course) plain `URLSession` from [Foundation]:

<pre><code>// pod 'CancelForPromiseKit/Foundation'
// # https://github.com/dougzilla32/CancelForPromiseKit-Foundation

<mark><b>let context =</b></mark> firstly {
    URLSession.shared.dataTask<mark><b>CC</b></mark>(.promise, with: try makeUrlRequest())
}.map {
    try JSONDecoder().decode(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark><b>.cancelContext</b></mark>

//…

<mark><b>context.cancel()</b></mark>

func makeUrlRequest() throws -> URLRequest {
    var rq = URLRequest(url: url)
    rq.httpMethod = "POST"
    rq.addValue("application/json", forHTTPHeaderField: "Content-Type")
    rq.addValue("application/json", forHTTPHeaderField: "Accept")
    rq.httpBody = try JSONSerialization.jsonData(with: obj)
    return rq
}
</code></pre>

# Design Goals

* **Provide a streamlined way to cancel a promise chain, which rejects all associated promises and cancels all associated tasks. For example:**

<pre><code><mark><b>let promise =</b></mark> firstly {
    login<mark><b>CC</b></mark>() // Use <b>CC</b> (a.k.a. cancel chain) methods or CancellablePromise to
              // initiate a cancellable promise chain
}.then { creds in
    fetch(avatar: creds.user)
}.done { image in
    self.imageView = image
}.catch(policy: .allErrors) { error in
    if <mark><b>error.isCancelled</b></mark> {
        // the chain has been cancelled!
    }
}
//…
<mark><b>promise.cancel()</b></mark>
</code></pre>

* **Ensure that subsequent code blocks in a promise chain are _never_ called after the chain has been cancelled**

* **Fully support concurrecy, where all code is thead-safe**

* **Provide cancellable varients for all appropriate PromiseKit extensions (e.g. Foundation, CoreLocation, Alamofire, etc.)**

* **Support cancellation for all PromiseKit primitives such as 'after', 'firstly', 'when', 'race'**

* **Provide a simple way to make new types of cancellable promises**

* **Ensure promise branches are properly cancelled.  For example:**

<pre><code>import Alamofire
import PromiseKit
import CancelForPromiseKit

func updateWeather(forCity searchName: String) {
    refreshButton.startAnimating()
    <mark><b>let context =</b></mark> firstly {
        getForecast(forCity: searchName)
    }.done { response in
        updateUI(forecast: response)
    }.ensure {
        refreshButton.stopAnimating()
    }.catch { error in
        // Cancellation errors are ignored by default
        showAlert(error: error) 
    }<mark><b>.cancelContext</b></mark>

    //…

    // <mark><b>**** Cancels EVERYTHING</b></mark> (however the 'ensure' block always executes regardless)
    <mark><b>context.cancel()</b></mark>
}

func getForecast(forCity name: String) -> <mark><b>CancellablePromise</b></mark>&lt;WeatherInfo&gt; {
    return firstly {
        Alamofire.request("https://autocomplete.weather.com/\(name)")
            .responseDecodable<mark><b>CC</b></mark>(AutoCompleteCity.self)
    }.then { city in
        Alamofire.request("https://forecast.weather.com/\(city.name)")
            .responseDecodable<mark><b>CC</b></mark>(WeatherResponse.self)
    }.map { response in
        format(response)
    }
}
</code></pre>

# Support

If you have a question or an issue to report, please use [my bug tracker].


[badge-pod]: https://img.shields.io/cocoapods/v/CancelForPromiseKit.svg?label=version
[badge-pms]: https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg
[badge-languages]: https://img.shields.io/badge/languages-Swift-orange.svg
[badge-platforms]: https://img.shields.io/cocoapods/p/CancelForPromiseKit.svg
[badge-mit]: https://img.shields.io/badge/license-MIT-blue.svg
[badge-docs]: https://dougzilla32.github.io/CancelForPromiseKit/api/badge.svg
[PromiseKit]: https://github.com/mxcl/PromiseKit
[PromiseKit Extensions]: https://github.com/PromiseKit
[PromiseKit README]: https://github.com/mxcl/PromiseKit/blob/master/README.md
[CancelForPromiseKit API Documentation]: https://dougzilla32.github.io/CancelForPromiseKit/api/
[CancelForPromiseKit]: https://github.com/dougzilla32/CancelForPromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancelForPromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancelForPromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
[my bug tracker]: https://github.com/dougzilla32/CancelForPromiseKit/issues/new
