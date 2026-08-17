import Foundation

/// Marks reflection offers as spoken only after the user can actually see them.
enum ReflectionOfferDisplayTracker {

    static func markDisplayed(_ offer: ReflectionOffer) {
        CoachUnderstandingStore.markSpoken(offer.id)
        if let raw = offer.beliefID, let beliefID = CoachBeliefID(rawValue: raw) {
            CoachDiscoveryStore.markSeen(beliefID: beliefID)
        }
    }
}
