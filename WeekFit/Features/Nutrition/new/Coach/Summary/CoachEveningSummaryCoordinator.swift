import Foundation
internal import Combine

@MainActor
final class CoachEveningSummaryCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case ready(CoachEveningSummary)
        case failed
    }
    @Published private(set) var status: Status = .idle
    private let store: CoachEveningSummaryStore
    private let generate: (CoachEveningSummaryInput, String) async throws -> CoachEveningSummary
    private var scope: String?
    private var task: Task<Void, Never>?
    private var deadline: Task<Void, Never>?

    init(store: CoachEveningSummaryStore = CoachEveningSummaryStore(),
         generate: @escaping (CoachEveningSummaryInput, String) async throws -> CoachEveningSummary = CoachEveningSummaryService.generate) {
        self.store = store
        self.generate = generate
    }

    func restore(owner: String, now: Date = Date(), calendar: Calendar = .current) {
        let day = CoachEveningSummaryPolicy.dayKey(now, calendar: calendar)
        let newScope = "\(owner)|\(day)"
        guard scope != newScope else { return }
        task?.cancel()
        deadline?.cancel()
        scope = newScope
        do {
            if let record = try store.record(owner: owner, day: day) {
                status = record.summary.map(Status.ready) ?? .failed
            } else { status = .idle }
        } catch { status = .failed }
    }

    func cancelForWorkspaceReset() {
        task?.cancel()
        deadline?.cancel()
        scope = nil
        status = .idle
    }

    func startIfNeeded(input: CoachEveningSummaryInput, owner: String, now: Date = Date(), calendar: Calendar = .current) {
        restore(owner: owner, now: now, calendar: calendar)
        guard CoachEveningSummaryPolicy.isEvening(now, calendar: calendar),
              input.day == CoachEveningSummaryPolicy.dayKey(now, calendar: calendar), status == .idle else { return }
        do {
            guard try store.claim(owner: owner, day: input.day) else { return }
        } catch { status = .failed; return }
        status = .loading
        let activeScope = scope
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await generate(input, owner)
                try Task.checkCancellation()
                guard scope == activeScope, status == .loading else { return }
                guard summary.isValid(for: input) else { throw CoachEveningSummaryServiceError.invalidResponse }
                try store.save(.init(day: input.day, summary: summary), owner: owner)
                status = .ready(summary)
            } catch {
                if scope == activeScope, status == .loading { status = .failed }
            }
            if scope == activeScope { deadline?.cancel() }
        }
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, scope == activeScope, status == .loading else { return }
            status = .failed
            task?.cancel()
        }
    }
}
