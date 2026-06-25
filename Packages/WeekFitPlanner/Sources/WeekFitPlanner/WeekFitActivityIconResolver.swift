import Foundation

public enum WeekFitActivityIconResolver {

    public static func resolve(for activity: PlannedActivity) -> String {
        resolve(
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
        let trimmedStoredIcon = storedIcon?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedStoredIcon.isEmpty {
            return trimmedStoredIcon
        }

        return canonical(title: title, type: type, imageName: imageName) ?? "sparkles"
    }

    public static func canonical(
        title: String,
        type: String,
        imageName: String? = nil
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
            || containsAny(haystack, ["banana", "meal", "breakfast", "lunch", "dinner", "snack", "toast", "apple"]) {
            return "fork.knife"
        }

        if containsAny(haystack, ["sauna", "heat", "саун"]) {
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

        if containsAny(haystack, [
            "upper body", "lower body", "full body", "strength", "gym", "training",
            "workout", "weights", "dumbbell", "сил", "зал"
        ]) {
            return "dumbbell.fill"
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

        if containsAny(haystack, ["sleep", "bedtime"]) {
            return "bed.double.fill"
        }

        if containsAny(haystack, ["no screens", "screen"]) {
            return "iphone.slash"
        }

        if containsAny(haystack, ["morning routine", "morning"]) {
            return "sunrise.fill"
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
}
