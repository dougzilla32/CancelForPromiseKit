# CancelForPromiseKit
![badge-pod] ![badge-languages] ![badge-pms] ![badge-platforms] ![badge-mit] [![Build Status](https://travis-ci.org/dougzilla32/CancelForPromiseKit.svg?branch=master)](https://travis-ci.org/dougzilla32/CancelForPromiseKit)

---

CancelForPromiseKit provides clear and concise cancellation abilities for [PromiseKit] and the [PromiseKit Extensions].  While PromiseKit includes basic support for cancellation, CancelForPromiseKit extends this to make cancelling promises and their associated tasks simple and straightforward.

The goals of this project are as follows:

* **A streamlined way to cancel a promise chain, which rejects all associated promises and cancels all associated tasks. For example:**

<pre><code><mark>let promise =</mark> firstly {
    login<mark>CC</mark>() // Use 'CC' (a.k.a. cancel chain) methods or CancellablePromise to
              // initiate a cancellable promise chain
}.then { creds in
    fetch(avatar: creds.user)
}.done { image in
    self.imageView = image
}.catch(policy: .allErrors) { error in
    if <mark>error.isCancelled</mark> {
        // the chain has been cancelled!
    }
}
//…
<mark>promise.cancel()</mark>
</code></pre>

Note: For all code samples, the differences between PromiseKit and CancelForPromiseKit are highlighted.

* **Ensure that subsequent code blocks in a promise chain are _NEVER_ called after the chain has been cancelled**

* **Provide cancellable varients for all appropriate PromiseKit extensions (e.g. Foundation, CoreLocation, Alamofire)**

* **Support cancellation for all PromiseKit primitives such as 'after', 'firstly', 'when', 'race'**

* **A simple way to make new types of cancellable promises**

* **Ensure branches are properly cancelled.  For example:**

<pre><code>import Alamofire
import PromiseKit
import CancelForPromiseKit

func updateWeather(forCity searchName: String) {
    refreshButton.startAnimating()
    <mark>let context =</mark> firstly {
        getForecast(forCity: searchName)
    }.done { response in
        updateUI(forecast: response)
    }.ensure {
        refreshButton.stopAnimating()
    }.catch { error in
        // Cancellation errors are ignored by default
        showAlert(error: error) 
    }<mark>.cancelContext</mark>

    //…

    // Cancels EVERYTHING (however the 'ensure' block always executes regardless)
    <mark>context.cancel()</mark>
}

func getForecast(forCity name: String) -> <mark>Cancellable</mark>Promise<WeatherInfo> {
    return firstly {
        Alamofire.request("https://autocomplete.weather.com/\(name)")
            .responseDecodable<mark>CC</mark>(AutoCompleteCity.self)
    }.then { city in
        Alamofire.request("https://forecast.weather.com/\(city.name)")
            .responseDecodable<mark>CC</mark>(WeatherResponse.self)
    }.map { response in
        format(response)
    }
}
</code></pre>

CancelForPromiseKit defines it's extensions as methods and functions with the 'CC' (cancel chain) suffix.

This README has the same structure as the [PromiseKit README], with cancellation added to the sample code blocks:

<pre><code>UIApplication.shared.isNetworkActivityIndicatorVisible = true

let fetchImage = URLSession.shared.dataTask<mark>CC</mark>(.promise, with: url).compactMap{ UIImage(data: $0.data) }
let fetchLocation = CLLocationManager.requestLocation<mark>CC</mark>().lastValue

// Hold on to the 'CancelContext' rather than the promise chain so the
// promises can be freed up.
<mark>let context =</mark> firstly {
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
}<mark>.cancelContext</mark>

//…

// Cancel currently active tasks and reject all promises with PromiseCancelledError
<mark>context.cancel()</mark>
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

# Documentation -- TBD

The following functions are part of the core CancelForPromiseKit module:

<pre><code>TODO: FIXME!!!
Global functions
	after<mark>CC</mark>(seconds:)
	after<mark>CC</mark>(_ interval:)
	
<mark>CancellablePromise</mark> methods
	value(_ value:)
	init(task:resolver:)
	init(task:bridge:)
	init(task:error:)
</code></pre>

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

<pre><code>pod "CancelForPromiseKit/MapKit"
# MKDirections().calculate<mark>CC</mark>().then { /*…*/ }

pod "CancelForPromiseKit/CoreLocation"
# CLLocationManager.requestLocation<mark>CC</mark>().then { /*…*/ }
</code></pre>

As with PromiseKit, all extensions are separate repositories.  Here is a complete list of CancelForPromiseKit extensions listing the specific functions that support cancellation (PromiseKit extensions without any functions supporting cancellation are omitted):

[Alamofire][Alamofire]  
<pre><code>Alamofire.DataRequest
	response<mark>CC</mark>(\_:queue:)
	responseData<mark>CC</mark>(queue:)
	responseString<mark>CC</mark>(queue:)
	responseJSON<mark>CC</mark>(queue:options:)
	responsePropertyList<mark>CC</mark>(queue:options:)
	responseDecodable<mark>CC</mark><T>(queue::decoder:)
	responseDecodable<mark>CC</mark><T>(_ type:queue:decoder:)

Alamofire.DownloadRequest
	response<mark>CC</mark>(_:queue:)
	responseData<mark>CC</mark>(queue:)
</code></pre>

[Bolts](http://github.com/dougzilla32/CancelForPromiseKit-Bolts)  
[Cloudkit](http://github.com/dougzilla32/CancelForPromiseKit-CloudKit)  
[CoreLocation](http://github.com/dougzilla32/CancelForPromiseKit-CoreLocation)  
[Foundation][Foundation]  

<pre><code>Process
	launch<mark>CC</mark>(_:)
		
URLSession
	dataTask<mark>CC</mark>(_:with:)
	uploadTask<mark>CC</mark>(_:with:from:)
	uploadTask<mark>CC</mark>(_:with:fromFile:)
	downloadTask<mark>CC</mark>(_:with:to:)
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

<mark>let context =</mark> firstly {
    Alamofire
        .request("http://example.com", method: .post, parameters: params)
        .responseDecodable<mark>CC</mark>(Foo.self, cancel: context)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark>.cancelContext</mark>

//…

<mark>context.cancel()</mark>
</code></pre>

[OMGHTTPURLRQ]:

<pre><code>
// pod 'CancelForPromiseKit/OMGHTTPURLRQ'
// # https://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ

<mark>let context =</mark> firstly {
    URLSession.shared.POST<mark>CC</mark>("http://example.com", JSON: params)
}.map {
    try JSONDecoder().decoder(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark>.cancelContext</mark>

//…

<mark>context.cancel()</mark>
</code></pre>

And (of course) plain `URLSession` from [Foundation]:

<pre><code>// pod 'CancelForPromiseKit/Foundation'
// # https://github.com/dougzilla32/CancelForPromiseKit-Foundation

<mark>let context =</mark> firstly {
    URLSession.shared.dataTask<mark>CC</mark>(.promise, with: try makeUrlRequest())
}.map {
    try JSONDecoder().decode(Foo.self, with: $0.data)
}.done { foo in
    //…
}.catch { error in
    //…
}<mark>.cancelContext</mark>

//…

<mark>context.cancel()</mark>

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
[PromiseKit]: https://github.com/mxcl/PromiseKit
[PromiseKit Extensions]: https://github.com/PromiseKit
[PromiseKit README]: https://github.com/mxcl/PromiseKit/blob/master/README.md
[CancelForPromiseKit]: https://github.com/dougzilla32/CancelForPromiseKit
[OMGHTTPURLRQ]: http://github.com/dougzilla32/CancelForPromiseKit-OMGHTTPURLRQ
[Alamofire]: http://github.com/dougzilla32/CancelForPromiseKit-Alamofire
[Foundation]: http://github.com/dougzilla32/CancelForPromiseKit-Foundation
[Podfile]: https://guides.cocoapods.org/syntax/podfile.html
