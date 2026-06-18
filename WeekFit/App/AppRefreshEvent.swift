import Foundation

enum AppRefreshKind: Equatable {
    case returnToToday
    case localDataResetCompleted
    case healthRefresh
    case coachRefresh
}

struct AppRefreshEvent: Equatable {
    let token: UUID
    let kind: AppRefreshKind
    let sources: [String]
    let createdAt: Date

    init(
        kind: AppRefreshKind,
        sources: [String] = [],
        token: UUID = UUID(),
        createdAt: Date = Date()
    ) {
        self.kind = kind
        self.sources = sources
        self.token = token
        self.createdAt = createdAt
    }
}
