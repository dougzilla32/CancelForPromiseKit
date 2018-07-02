import Foundation
import PromiseKit

#if Carthage
import PMKFoundation
#else
#if swift(>=4.1)
#if canImport(PMKFoundation)
import PMKFoundation
#endif
#endif
#endif

#if !CPKCocoaPods
import CancelForPromiseKit
#endif

extension URLSessionTask: CancellableTask {
    /// `true` if the URLSessionTask was successfully cancelled, `false` otherwise
    public var isCancelled: Bool {
        return state == .canceling
    }
}

/**
 To import the `NSURLSession` category:

    use_frameworks!
    pod "CancelForPromiseKit/Foundation"

 Or `NSURLSession` is one of the categories imported by the umbrella pod:

    use_frameworks!
    pod "CancelForPromiseKit"

 And then in your sources:

    import PromiseKit
    import CancelForPromiseKit
*/
extension URLSession {
    /**
     Example usage with explicit cancel context:

         let context = firstly {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMap { data, _ in
             try JSONSerialization.jsonObject(with: data) as? [String: Any]
         }.then { json in
             //…
         }.cancelContext
         //…
         context.cancel()

     Example usage with implicit cancel context:
     
         let promise = firstly {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMap { data, _ in
             try JSONSerialization.jsonObject(with: data) as? [String: Any]
         }.then { json in
             //…
         }
         //…
         promise.cancel()
     
     We recommend the use of [OMGHTTPURLRQ] which allows you to construct correct REST requests:

         let context = firstly {
             let rq = OMGHTTPURLRQ.POST(url, json: parameters)
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.then { data, urlResponse in
             //…
         }.cancelContext
         //…
         context.cancel()

     We provide a convenience initializer for `String` specifically for this promise:
     
         let context = firstly {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMap(String.init).then { string in
             // decoded per the string encoding specified by the server
         }.then { string in
             print("response: string")
         }
         //…
         context.cancel()
     
     Other common types can be easily decoded using compactMap also:
     
         let context = firstly {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMap {
             UIImage(data: $0)
         }.then {
             self.imageView.image = $0
         }
         //…
         context.cancel()

     Though if you do decode the image this way, we recommend inflating it on a background thread
     first as this will improve main thread performance when rendering the image:
     
         let context = firstly {
             URLSession.shared.dataTaskCC(.promise, with: rq)
         }.compactMap(on: QoS.userInitiated) { data, _ in
             guard let img = UIImage(data: data) else { return nil }
             _ = cgImage?.dataProvider?.data
             return img
         }.then {
             self.imageView.image = $0
         }
         //…
         context.cancel()

     - Parameter convertible: A URL or URLRequest.
     - Returns: A cancellable promise that represents the URL request.
     - SeeAlso: [OMGHTTPURLRQ]
     - Remark: We deliberately don’t provide a `URLRequestConvertible` for `String` because in our experience, you should be explicit with this error path to make good apps.
     
     [OMGHTTPURLRQ]: https://github.com/mxcl/OMGHTTPURLRQ
     */
    public func dataTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible) -> CancellablePromise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = CancellablePromise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.dataTask(with: convertible.pmkRequest, completionHandler: adapter($0))
            task.resume()
        }

        promise.appendCancellableTask(task: task, reject: reject)
        return promise
    }

    /// Wraps the (Data?, URLResponse?, Error?) response from URLSession.uploadTask(with:from:) as CancellablePromise<(Data,URLResponse)>
    public func uploadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, from data: Data) -> CancellablePromise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!
        
        let promise = CancellablePromise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.uploadTask(with: convertible.pmkRequest, from: data, completionHandler: adapter($0))
            task.resume()
        }

        promise.appendCancellableTask(task: task, reject: reject)
        return promise
    }

    /// Wraps the (Data?, URLResponse?, Error?) response from URLSession.uploadTask(with:fromFile:) as CancellablePromise<(Data,URLResponse)>
    public func uploadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, fromFile file: URL) -> CancellablePromise<(data: Data, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = CancellablePromise<(data: Data, response: URLResponse)> {
            reject = $0.reject
            task = self.uploadTask(with: convertible.pmkRequest, fromFile: file, completionHandler: adapter($0))
            task.resume()
        }

        promise.appendCancellableTask(task: task, reject: reject)
        return promise
    }

    /**
     Wraps the URLSesstionDownloadTask response from URLSession.downloadTask(with:) as CancellablePromise<(URL,URLResponse)>
     - Remark: we force a `to` parameter because Apple deletes the downloaded file immediately after the underyling completion handler returns.
     */
    public func downloadTaskCC(_: PMKNamespacer, with convertible: URLRequestConvertible, to saveLocation: URL) -> CancellablePromise<(saveLocation: URL, response: URLResponse)> {
        var task: URLSessionTask!
        var reject: ((Error) -> Void)!

        let promise = CancellablePromise<(saveLocation: URL, response: URLResponse)> { seal in
            reject = seal.reject
            task = self.downloadTask(with: convertible.pmkRequest, completionHandler: { tmp, rsp, err in
                if let error = err {
                    seal.reject(error)
                } else if let rsp = rsp, let tmp = tmp {
                    do {
                        try FileManager.default.moveItem(at: tmp, to: saveLocation)
                        seal.fulfill((saveLocation, rsp))
                    } catch {
                        seal.reject(error)
                    }
                } else {
                    seal.reject(PMKError.invalidCallingConvention)
                }
            })
            task.resume()
        }

        promise.appendCancellableTask(task: task, reject: reject)
        return promise
    }
}

private func adapter<T, U>(_ seal: Resolver<(data: T, response: U)>) -> (T?, U?, Error?) -> Void {
    return { t, u, e in
        if let t = t, let u = u {
            seal.fulfill((t, u))
        } else if let e = e {
            seal.reject(e)
        } else {
            seal.reject(PMKError.invalidCallingConvention)
        }
    }
}
