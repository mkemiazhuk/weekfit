import XCTest
@testable import WeekFit

final class AppleIdentityStoreTests: XCTestCase {

    private let testUserID = "apple-identity-store-test-user"

    override func tearDown() {
        AppleIdentityStore.clear(appleUserID: testUserID)
        super.tearDown()
    }

    func testMergeKeepsEarlierNameWhenLaterCredentialOmitsIt() {
        AppleIdentityStore.merge(
            appleUserID: testUserID,
            displayName: "Maksim",
            givenName: "Maksim",
            email: "a@b.com"
        )
        AppleIdentityStore.merge(
            appleUserID: testUserID,
            displayName: nil,
            givenName: nil,
            email: nil
        )

        let record = AppleIdentityStore.load(appleUserID: testUserID)
        XCTAssertEqual(record?.displayName, "Maksim")
        XCTAssertEqual(record?.givenName, "Maksim")
        XCTAssertEqual(record?.email, "a@b.com")
    }

    func testParserNilWhenAppleWithholds() {
        XCTAssertNil(ApplePersonNameParser.parse(nil))
        XCTAssertNil(ApplePersonNameParser.parse(PersonNameComponents()))
    }
}
