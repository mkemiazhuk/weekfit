import Foundation

/// Locale-aware parsing of Apple `PersonNameComponents` for profile persistence.
enum ApplePersonNameParser {

    struct ParsedName: Equatable, Sendable {
        let givenName: String?
        let familyName: String?
        /// Locale-aware display string from `PersonNameComponentsFormatter`.
        let displayName: String
    }

    /// Returns nil when Apple withheld the name or all components are empty/whitespace.
    static func parse(_ components: PersonNameComponents?) -> ParsedName? {
        guard let components else { return nil }
        guard let sanitized = sanitizedComponents(from: components) else { return nil }

        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let display = formatter.string(from: sanitized)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !display.isEmpty else { return nil }

        return ParsedName(
            givenName: clean(sanitized.givenName),
            familyName: clean(sanitized.familyName),
            displayName: display
        )
    }

    private static func sanitizedComponents(from components: PersonNameComponents) -> PersonNameComponents? {
        var sanitized = PersonNameComponents()
        sanitized.givenName = clean(components.givenName)
        sanitized.familyName = clean(components.familyName)
        sanitized.middleName = clean(components.middleName)
        sanitized.namePrefix = clean(components.namePrefix)
        sanitized.nameSuffix = clean(components.nameSuffix)
        sanitized.nickname = clean(components.nickname)

        let hasAny =
            sanitized.givenName != nil ||
            sanitized.familyName != nil ||
            sanitized.middleName != nil ||
            sanitized.nickname != nil ||
            sanitized.namePrefix != nil ||
            sanitized.nameSuffix != nil
        return hasAny ? sanitized : nil
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
