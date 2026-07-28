import Foundation
import UIKit

protocol FeedbackSubmissionServing: AnyObject {
    @MainActor
    func submit(_ submission: FeedbackSubmission) async throws
}

enum FeedbackSubmissionError: Error, Equatable {
    case emptyMessage
    case unavailable
}

/// Protocol-based feedback sink with a safe mailto fallback.
/// Does not transmit HealthKit data, auth tokens, or personal health values.
@MainActor
final class MailtoFeedbackSubmissionService: FeedbackSubmissionServing {
    private let supportEmail: String
    private let openURL: (URL) -> Void
    private let copyFallback: (String) -> Void

    init(
        supportEmail: String = "support@weekfit.app",
        openURL: @escaping (URL) -> Void = { UIApplication.shared.open($0) },
        copyFallback: @escaping (String) -> Void = { UIPasteboard.general.string = $0 }
    ) {
        self.supportEmail = supportEmail
        self.openURL = openURL
        self.copyFallback = copyFallback
    }

    func submit(_ submission: FeedbackSubmission) async throws {
        let trimmed = submission.draft.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FeedbackSubmissionError.emptyMessage }

        let subject = subjectLine(for: submission)
        let body = composedBody(for: submission, message: trimmed)

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else {
            copyFallback("\(supportEmail)\n\n\(body)")
            throw FeedbackSubmissionError.unavailable
        }

        openURL(url)
    }

    private func subjectLine(for submission: FeedbackSubmission) -> String {
        switch submission.draft.intent {
        case .suggestFeature:
            return "WeekFit Feature Suggestion"
        case .reportProblem:
            return "WeekFit Problem Report"
        case .postSentiment, .general:
            if let category = submission.draft.category {
                return "WeekFit Feedback — \(category.rawValue)"
            }
            return "WeekFit Feedback"
        }
    }

    private func composedBody(for submission: FeedbackSubmission, message: String) -> String {
        let meta = submission.metadata.dictionaryRepresentation
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")

        var lines: [String] = [
            "Hi WeekFit Team,",
            "",
            message,
            ""
        ]

        if let sentiment = submission.draft.sentiment {
            lines.append("Sentiment: \(sentiment.analyticsName)")
        }
        if submission.draft.allowContact {
            lines.append("Contact permission: yes — you may contact me about this feedback.")
        } else {
            lines.append("Contact permission: no")
        }

        lines.append("")
        lines.append("---")
        lines.append(meta)
        lines.append("")
        lines.append("(No HealthKit or personal health values are included.)")

        return lines.joined(separator: "\n")
    }
}

final class RecordingFeedbackSubmissionService: FeedbackSubmissionServing {
    private(set) var submissions: [FeedbackSubmission] = []
    var errorToThrow: FeedbackSubmissionError?

    @MainActor
    func submit(_ submission: FeedbackSubmission) async throws {
        if let errorToThrow { throw errorToThrow }
        submissions.append(submission)
    }
}
