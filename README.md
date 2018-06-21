# CancelForPromiseKit
![badge-pod] ![badge-languages] ![badge-pms] ![badge-platforms] ![badge-mit] [![Build Status](https://travis-ci.org/dougzilla32/CancelForPromiseKit.svg?branch=master)](https://travis-ci.org/dougzilla32/CancelForPromiseKit) ![badge-docs]

---

CancelForPromiseKit provides clear and concise cancellation abilities for [PromiseKit] and the [PromiseKit Extensions].  While PromiseKit includes basic support for cancellation, CancelForPromiseKit extends this to make cancelling promises and their associated tasks simple and straightforward.

This README has the same structure as the [PromiseKit README], with cancellation added to the sample code blocks:

<pre><code>UIApplication.shared.isNetworkActivityIndicatorVisible = true

let fetchImage = URLSession.shared.dataTask<mark><b>CC</b></mark>(.promise, with: url).compactMap{ UIImage(data: $0.data) }
let fetchLocation = CLLocationManager.requestLocation<mark><b>CC</b></mark>().lastValue

// Hold on to the <b>CancelContext</b> rather than the promise chain so the
// promises can be freed up.
<mark><b>let context =</b></mark> firstly {
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
}<mark><b>.cancelContext</b></mark>

//…

// Cancel currently active tasks and reject all promises with PromiseCancelledError
<mark><b>context.cancel()</b></mark>
</code></pre>

Note: For all code samples, the differences between PromiseKit and CancelForPromiseKit are highlighted in bold.

# Goals

The goals of this project are to:

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

* **Ensure that subsequent code blocks in a promise chain are _NEVER_ called after the chain has been cancelled**

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

# Quick Start

In your [Podfile]:

<pre><code>use_frameworks!

target "Change Me!" do
  pod "PromiseKit", "~> 6.0"
  pod "CancelForPromiseKit", "~> 1.0"
end
</code></pre>

CancelForPromiseKit has the same platform and XCode support as PromiseKit

# Documentation

The following functions and methods are part of the core CancelForPromiseKit module.  Functions and Methods with the <b>CC</b> suffix create a new CancellablePromise,
and those without the <b>CC</b> suffix accept an existing CancellablePromise:

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

[badge-pod]: https://img.shields.io/cocoapods/v/CancelForPromiseKit.svg?label=version
[badge-pms]: https://img.shields.io/badge/supports-CocoaPods%20%7C%20Carthage%20%7C%20SwiftPM-green.svg
[badge-languages]: https://img.shields.io/badge/languages-Swift-orange.svg
[badge-platforms]: https://img.shields.io/cocoapods/p/CancelForPromiseKit.svg
[badge-mit]: https://img.shields.io/badge/license-MIT-blue.svg
[badge-docs]: https://raw.githubusercontent.com/dougzilla32/CancelForPromiseKit/master/api/badge.svg
[PromiseKit]: https://github.com/mxcl/PromiseKit
[PromiseKit Extensions]: https://github.com/PromiseKit
[PromiseKit README]: https://github.com/mxcl/PromiseKit/blob/master/README.md
[CancelForPromiseKit]: https://github.com/dougzilla32/CancelForPromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancelForPromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancelForPromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
