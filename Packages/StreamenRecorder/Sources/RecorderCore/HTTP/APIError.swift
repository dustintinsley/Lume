import Foundation
import Hummingbird
import StreamenRecorderKit

/// An error rendered as `{"error":{"code":…,"message":…}}`.
public struct APIError: HTTPResponseError, Sendable {
    public let status: HTTPResponse.Status
    public let code: String
    public let message: String

    public init(_ status: HTTPResponse.Status, code: String, message: String) {
        self.status = status
        self.code = code
        self.message = message
    }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        try JSONResponse.make(ErrorResponse(code: code, message: message), status: status)
    }

    public static let unauthorized = APIError(.unauthorized, code: StreamenRecorderErrorCode.unauthorized, message: "Missing or invalid bearer token.")
    public static let pairingInvalid = APIError(.unauthorized, code: StreamenRecorderErrorCode.pairingInvalid, message: "The pairing code is wrong or has expired.")
    public static let rateLimited = APIError(.tooManyRequests, code: StreamenRecorderErrorCode.rateLimited, message: "Too many failed pairing attempts. Try again in a minute.")
    public static let notFound = APIError(.notFound, code: StreamenRecorderErrorCode.notFound, message: "Not found.")
    public static let forbidden = APIError(.forbidden, code: StreamenRecorderErrorCode.forbidden, message: "Invalid or expired playback link.")
    public static let insufficientStorageStatus = HTTPResponse.Status(code: 507, reasonPhrase: "Insufficient Storage")

    public static func invalidRequest(_ message: String) -> APIError {
        APIError(.badRequest, code: StreamenRecorderErrorCode.invalidRequest, message: message)
    }

    /// Maps domain errors onto API errors.
    public static func from(_ error: RecorderError) -> APIError {
        switch error {
        case let .invalidRequest(message):
            invalidRequest(message)
        case .notFound:
            notFound
        case .concurrencyLimit:
            APIError(.conflict, code: StreamenRecorderErrorCode.concurrencyLimit, message: "The maximum number of simultaneous recordings is already running.")
        case .insufficientStorage:
            APIError(insufficientStorageStatus, code: StreamenRecorderErrorCode.insufficientStorage, message: "Not enough free disk space on the recorder.")
        case .notPlayable:
            APIError(.conflict, code: StreamenRecorderErrorCode.notPlayable, message: "This recording has no media to play yet.")
        }
    }
}

enum JSONResponse {
    static func make(_ value: some Encodable, status: HTTPResponse.Status = .ok) throws -> Response {
        let data = try StreamenRecorderCoding.makeEncoder().encode(value)
        var headers = HTTPFields()
        headers[.contentType] = "application/json; charset=utf-8"
        headers[.cacheControl] = "no-store"
        return Response(status: status, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: data)))
    }
}

/// Turns every error — ours, Hummingbird's (`HTTPError`, e.g. unknown route
/// or undecodable body) and unexpected ones — into the JSON error shape.
struct ErrorMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let error as APIError {
            return try error.response(from: request, context: context)
        } catch let error as RecorderError {
            return try APIError.from(error).response(from: request, context: context)
        } catch let error as HTTPError {
            let code = switch error.status.code {
            case 400, 413: StreamenRecorderErrorCode.invalidRequest
            case 401: StreamenRecorderErrorCode.unauthorized
            case 403: StreamenRecorderErrorCode.forbidden
            case 404: StreamenRecorderErrorCode.notFound
            case 405: "method_not_allowed"
            default: "http_\(error.status.code)"
            }
            let message = error.body ?? error.status.reasonPhrase
            return try APIError(error.status, code: code, message: message).response(from: request, context: context)
        } catch {
            context.logger.error("Unhandled error: \(String(reflecting: type(of: error)))")
            return try APIError(.internalServerError, code: StreamenRecorderErrorCode.internalError, message: "Internal server error.")
                .response(from: request, context: context)
        }
    }
}
