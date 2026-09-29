import Foundation

/// A recoverable application error with a message suitable for an alert.
enum AppError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let message): return message
    }
  }
}
