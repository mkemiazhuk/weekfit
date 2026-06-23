import Foundation
import Observation

@Observable
final class QuickLogSessionStore {
    private(set) var selections: [String: QuickLogSelection] = [:]

    var onSheetDismissRequest: ((String) -> Void)?

    private var dismissTasks: [String: Task<Void, Never>] = [:]
    private var adjustedItemIDs: Set<String> = []

    private let fastDismissDelay: Duration = .milliseconds(500)
    private let stepperDismissDelay: Duration = .milliseconds(1200)

    func selection(for itemID: String) -> QuickLogSelection {
        selections[itemID] ?? QuickLogSelection()
    }

    func isExpanded(itemID: String) -> Bool {
        selections[itemID]?.isExpanded ?? false
    }

    @discardableResult
    func quickAdd(profile: QuickLogNutritionProfile) -> QuickLogSelection {
        var selection = selections[profile.id] ?? QuickLogSelection()

        if selection.isSelected {
            selection.isExpanded = true
        } else {
            selection = QuickLogServingMath.defaultSelection(for: profile)
            selection.isExpanded = true
        }

        selections[profile.id] = selection
        scheduleAutoDismiss(for: profile.id)
        return selection
    }

    func increment(profile: QuickLogNutritionProfile) {
        var selection = selections[profile.id] ?? QuickLogSelection(portions: 1)
        selection.portions += 1
        selection.mode = .portions
        selection.alternateAmount = nil
        selection.isExpanded = true
        selections[profile.id] = selection
        adjustedItemIDs.insert(profile.id)
        scheduleAutoDismiss(for: profile.id)
    }

    func decrement(profile: QuickLogNutritionProfile) {
        guard var selection = selections[profile.id], selection.isSelected else { return }

        selection.portions = max(selection.portions - 1, 0)
        selection.mode = .portions
        selection.alternateAmount = nil

        if selection.portions <= 0 {
            selections.removeValue(forKey: profile.id)
            adjustedItemIDs.remove(profile.id)
            cancelAutoDismiss(for: profile.id)
        } else {
            selection.isExpanded = true
            selections[profile.id] = selection
            adjustedItemIDs.insert(profile.id)
            scheduleAutoDismiss(for: profile.id)
        }
    }

    func attachActivityID(_ activityID: String, to itemID: String) {
        guard var selection = selections[itemID] else { return }
        selection.loggedActivityID = activityID
        selections[itemID] = selection
    }

    func clearActivityID(for itemID: String) {
        guard var selection = selections[itemID] else { return }
        selection.loggedActivityID = nil
        selections[itemID] = selection
    }

    func reset() {
        dismissTasks.values.forEach { $0.cancel() }
        dismissTasks.removeAll()
        adjustedItemIDs.removeAll()
        selections.removeAll()
        onSheetDismissRequest = nil
    }

    private func dismissDelay(for itemID: String) -> Duration {
        guard let selection = selections[itemID], selection.isSelected else {
            return stepperDismissDelay
        }

        // While the inline stepper is visible, always give time to adjust quantity.
        if selection.isExpanded {
            return stepperDismissDelay
        }

        if adjustedItemIDs.contains(itemID) || selection.portions > 1 {
            return stepperDismissDelay
        }

        return fastDismissDelay
    }

    private func scheduleAutoDismiss(for itemID: String) {
        dismissTasks[itemID]?.cancel()
        let delay = dismissDelay(for: itemID)

        dismissTasks[itemID] = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            guard selections[itemID]?.isSelected == true else { return }

            dismissTasks[itemID] = nil
            onSheetDismissRequest?(itemID)
        }
    }

    private func cancelAutoDismiss(for itemID: String) {
        dismissTasks[itemID]?.cancel()
        dismissTasks[itemID] = nil
    }
}
