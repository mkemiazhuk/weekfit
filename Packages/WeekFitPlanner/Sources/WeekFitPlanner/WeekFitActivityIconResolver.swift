import Foundation

public enum WeekFitActivityIconResolver {

    /// Planner catalog imageName → SF Symbol (authoritative for saved Plan options).
    private static let imageNameIcons: [String: String] = [
        "workout-cycling": "figure.outdoor.cycle",
        "workout-running": "figure.run",
        "workout-swimming": "figure.pool.swim",
        "workout-hiking": "figure.hiking",
        "workout-strength": "dumbbell.fill",
        "workout-core": "figure.core.training",
        "workout-lowerbody": "figure.strengthtraining.traditional",
        "workout-fullbody": "figure.strengthtraining.functional",
        "workout-tennis": "figure.tennis",
        "workout-squash": "figure.squash",
        "recovery-stretch": "figure.cooldown",
        "recovery-walk": "figure.walk",
        "recovery-sauna": "flame.fill",
        "recovery-yoga": "figure.yoga",
        "recovery-breathing": "wind",
        "habit-water": "drop.fill",
        "habit-sleep": "moon.stars.fill",
        "habit-noscreens": "iphone.slash",
        "habit-morning": "sun.max.fill",
        "hydration": "drop.fill"
    ]

    /// Exact English catalog titles stored on PlannedActivity.
    private static let titleIcons: [String: String] = [
        "cycling": "figure.outdoor.cycle",
        "outdoor cycle": "figure.outdoor.cycle",
        "long endurance ride": "figure.outdoor.cycle",
        "running": "figure.run",
        "swimming": "figure.pool.swim",
        "hiking": "figure.hiking",
        "upper body": "dumbbell.fill",
        "core": "figure.core.training",
        "core training": "figure.core.training",
        "lower body": "figure.strengthtraining.traditional",
        "full body": "figure.strengthtraining.functional",
        "strength workout": "dumbbell.fill",
        "hiit workout": "flame.fill",
        "tennis": "figure.tennis",
        "squash": "figure.squash",
        "snowboarding": "figure.snowboarding",
        "stretching": "figure.cooldown",
        "walk": "figure.walk",
        "sauna": "flame.fill",
        "yoga": "figure.yoga",
        "breathing": "wind",
        "drink water": "drop.fill",
        "water": "drop.fill",
        "sleep routine": "moon.stars.fill",
        "no screens": "iphone.slash",
        "morning routine": "sun.max.fill"
    ]

    public static func resolve(for activity: PlannedActivity) -> String {
        preferredIcon(
            storedIcon: activity.icon,
            title: activity.title,
            type: activity.type,
            imageName: activity.imageName
        )
    }

    public static func resolve(
        storedIcon: String?,
        title: String,
        type: String,
        imageName: String? = nil
    ) -> String {
        preferredIcon(
            storedIcon: storedIcon,
            title: title,
            type: type,
            imageName: imageName
        )
    }

    /// Best icon to display and persist for an activity.
    public static func preferredIcon(
        storedIcon: String?,
        title: String,
        type: String,
        imageName: String? = nil
    ) -> String {
        if let catalog = catalogIcon(title: title, type: type, imageName: imageName) {
            return catalog
        }

        if let heuristic = heuristicIcon(title: title, type: type, imageName: imageName) {
            return heuristic
        }

        let trimmedStored = storedIcon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedStored.isEmpty {
            return trimmedStored
        }

        return "sparkles"
    }

    public static func canonical(
        title: String,
        type: String,
        imageName: String? = nil
    ) -> String? {
        catalogIcon(title: title, type: type, imageName: imageName)
            ?? heuristicIcon(title: title, type: type, imageName: imageName)
    }

    /// Type-level placeholders saved when an option-specific icon was not persisted.
    public static func isGenericCategoryIcon(_ icon: String) -> Bool {
        switch icon.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "dumbbell.fill",
             "leaf.fill",
             "fork.knife",
             "checkmark.square",
             "checkmark.circle",
             "checkmark.circle.fill",
             "sparkles":
            return true
        default:
            return false
        }
    }

    // MARK: - Catalog

    private static func catalogIcon(
        title: String,
        type: String,
        imageName: String?
    ) -> String? {
        let normalizedImage = imageName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if let mapped = imageNameIcons[normalizedImage] {
            return mapped
        }

        // Strip path/extension variants if any.
        if let slash = normalizedImage.split(separator: "/").last,
           let mapped = imageNameIcons[String(slash)] {
            return mapped
        }

        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let mapped = titleIcons[normalizedTitle] {
            return mapped
        }

        return nil
    }

    // MARK: - Heuristics

    private static func heuristicIcon(
        title: String,
        type: String,
        imageName: String?
    ) -> String? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedImageName = imageName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let haystack = [normalizedTitle, normalizedType, normalizedImageName].joined(separator: " ")

        if normalizedType == "drink"
            || normalizedType == "hydration"
            || containsAny(haystack, ["water", "hydration", "вода"]) {
            return "drop.fill"
        }

        if containsAny(haystack, ["coffee", "espresso", "cappuccino", "latte", "tea", "кофе", "чай"]) {
            return "cup.and.saucer.fill"
        }

        if normalizedType == "meal"
            || normalizedType == "snack"
            || containsAny(haystack, ["banana", "meal", "breakfast", "lunch", "dinner", "snack", "toast", "apple", "protein", "shake"]) {
            return "fork.knife"
        }

        if containsAny(haystack, ["sauna", "саун"]) || containsToken(haystack, ["heat"]) {
            return "flame.fill"
        }

        if containsAny(haystack, ["walk", "walking", "ходь", "прогул"]) {
            return "figure.walk"
        }

        if containsAny(haystack, ["hike", "hiking", "поход"]) {
            return "figure.hiking"
        }

        if containsAny(haystack, ["running", "run", "бег"]) {
            return "figure.run"
        }

        if containsAny(haystack, ["cycling", "cycle", "bike", "ride", "bicycle", "вел", "вело"]) {
            return "figure.outdoor.cycle"
        }

        if containsAny(haystack, ["yoga", "йога"]) {
            return "figure.yoga"
        }

        if containsAny(haystack, ["breathing", "breath", "дых"]) {
            return "wind"
        }

        if containsAny(haystack, ["stretch", "stretching", "mobility", "flexibility", "растяж", "мобил", "cooldown"]) {
            return "figure.cooldown"
        }

        if containsAny(haystack, ["swim", "swimming", "плав"]) {
            return "figure.pool.swim"
        }

        if containsAny(haystack, ["hiit", "interval"]) {
            return "flame.fill"
        }

        if containsAny(haystack, ["tennis"]) {
            return "figure.tennis"
        }

        if containsAny(haystack, ["squash"]) {
            return "figure.squash"
        }

        if containsAny(haystack, ["snowboard"]) {
            return "figure.snowboarding"
        }

        if containsAny(haystack, ["core", "abs", "abdominal", "кор", "пресс"]) {
            return "figure.core.training"
        }

        if containsAny(haystack, ["lower body"]) {
            return "figure.strengthtraining.traditional"
        }

        if containsAny(haystack, ["full body", "functional"]) {
            return "figure.strengthtraining.functional"
        }

        if containsAny(haystack, [
            "upper body", "strength", "gym", "weights", "dumbbell", "сил", "зал"
        ]) {
            return "dumbbell.fill"
        }

        if containsAny(haystack, ["sleep", "bedtime"]) {
            return "moon.stars.fill"
        }

        if containsAny(haystack, ["no screens", "screen"]) {
            return "iphone.slash"
        }

        if containsAny(haystack, ["morning routine"]) {
            return "sunrise.fill"
        }

        if containsAny(haystack, ["morning"]) && normalizedType == "habit" {
            return "sun.max.fill"
        }

        // Generic workout type without a more specific title match.
        if normalizedType == "workout" || containsToken(haystack, ["workout", "training"]) {
            return "dumbbell.fill"
        }

        if normalizedType == "habit" || containsAny(haystack, ["routine"]) {
            return "checkmark.circle"
        }

        if normalizedType == "recovery" {
            return "leaf.fill"
        }

        return nil
    }

    private static func containsAny(_ text: String, _ tokens: [String]) -> Bool {
        tokens.contains { text.contains($0) }
    }

    private static func containsToken(_ text: String, _ tokens: [String]) -> Bool {
        let parts = text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        return tokens.contains { token in
            parts.contains(token.lowercased())
        }
    }
}

// MARK: - Persistence repair

public enum WeekFitActivityIconRepair {

    /// Rewrites stored icons to the preferred catalog/heuristic icon.
    /// Returns the number of activities updated.
    @discardableResult
    public static func repairIcons(in activities: [PlannedActivity]) -> Int {
        var repaired = 0

        for activity in activities {
            let preferred = WeekFitActivityIconResolver.preferredIcon(
                storedIcon: activity.icon,
                title: activity.title,
                type: activity.type,
                imageName: activity.imageName
            )

            if activity.icon != preferred {
                activity.icon = preferred
                repaired += 1
            }
        }

        return repaired
    }
}
