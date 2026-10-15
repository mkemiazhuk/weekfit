import Foundation

/// Tracks when the request body has finished sending so UI can move from upload → wait.
final class PhotoFoodUploadSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var uploadFinishedHandlers: [UUID: @Sendable () -> Void] = [:]

    lazy var session: URLSession = {
        // Default config reuses TLS connections to the Nutrition host across accept + polls.
        let config = URLSessionConfiguration.default
        // Overall wall clock is enforced by the recognition client task group.
        config.timeoutIntervalForRequest = PhotoFoodRecognitionClient.overallDeadlineSeconds
        config.timeoutIntervalForResource = PhotoFoodRecognitionClient.overallDeadlineSeconds
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func onUploadFinished(_ handler: @escaping @Sendable () -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        uploadFinishedHandlers[id] = handler
        lock.unlock()
        return id
    }

    func removeUploadFinishedHandler(_ id: UUID) {
        lock.lock()
        uploadFinishedHandlers[id] = nil
        lock.unlock()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0, totalBytesSent >= totalBytesExpectedToSend else { return }
        lock.lock()
        let handlers = Array(uploadFinishedHandlers.values)
        lock.unlock()
        for handler in handlers {
            handler()
        }
    }
}
