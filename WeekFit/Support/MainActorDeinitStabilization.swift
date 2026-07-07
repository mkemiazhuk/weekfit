import Foundation

/// Why some MainActor-default-isolated reference types declare `nonisolated deinit`.
///
/// Workaround for Swift Concurrency `TaskLocal` bad-free during synchronous `@MainActor` XCTest
/// teardown under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
///
/// Do not remove `nonisolated deinit` from affected types unless the project removes default
/// MainActor isolation or XCTest teardown is converted to async.
enum MainActorDeinitStabilization {}
