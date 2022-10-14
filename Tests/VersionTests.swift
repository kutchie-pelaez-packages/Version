@testable import Version
import Core
import XCTest

final class VersionTests: XCTestCase {
    func test1_throwInitializationErrors() {
        XCTAssertTrue((try! Version("2.0.0-alpha")) > (try! Version("1.0.0")))

        assertInitializingErrorEqual(to: .invalidCoreFormat(""), for: "")
        assertInitializingErrorEqual(to: .invalidCoreFormat(""), for: "-123")
        assertInitializingErrorEqual(to: .invalidCoreFormat(""), for: "+ABC")
        assertInitializingErrorEqual(to: .invalidCoreFormat(""), for: "-123+ABC")
        assertInitializingErrorEqual(to: .invalidCoreFormat("1 "), for: "1 ")
        assertInitializingErrorEqual(to: .invalidCoreFormat("1.2.~"), for: "1.2.~")
        assertInitializingErrorEqual(to: .invalidCoreFormat("1.2.3.4"), for: "1.2.3.4")
        assertInitializingErrorEqual(to: .emptyBuild, for: "1.0.0+")
        assertInitializingErrorEqual(to: .emptyBuild, for: "1.0.0-+")
        assertInitializingErrorEqual(to: .emptyPreRelease, for: "1.0.0-")
        assertInitializingErrorEqual(to: .multipleBuildMetadata(["A", "AA"]), for: "1.0.0+A+AA")
        assertInitializingErrorEqual(to: .invalidBuildMetadataIdentifiers(["~", "~"]), for: "1.0.0+~.~")
        assertInitializingErrorEqual(to: .invalidPreReleaseMetadataIdentifiers(["~", "~"]), for: "1.0.0-~.~")
        assertInitializingErrorEqual(to: .invalidBuildMetadataIdentifiers(["~", "~"]), for: "1.0.0-~+~.~")
        assertInitializingErrorEqual(to: .emptyBuild) { try Version(1, 0, 0, build: "") }
        assertInitializingErrorEqual(to: .emptyBuild) { try Version(1, 0, 0, preRelease: "", build: "") }
        assertInitializingErrorEqual(to: .emptyPreRelease) { try Version(1, 0, 0, preRelease: "") }
    }

    func test2_testVersionsEquality() {
        assertEqual("1") { Version(1, 0, 0) }
        assertEqual("1.0") { Version(1, 0, 0) }
        assertEqual("1.0.0") { Version(1, 0, 0) }

        assertEqual("1.0.0+ABC") { try Version(1, 0, 0, build: "ABC") }
        assertEqual("1.0.0+123") { try Version(1, 0, 0, build: "123") }
        assertEqual("1.0.0+ABC.123") { try Version(1, 0, 0, build: "ABC.123") }
        assertEqual("1.0.0+123.ABC") { try Version(1, 0, 0, build: "123.ABC") }
        assertEqual("1.0.0+ABC.-") { try Version(1, 0, 0, build: "ABC.-") }

        assertEqual("1.0.0-ABC") { try Version(1, 0, 0, preRelease: "ABC") }
        assertEqual("1.0.0-123") { try Version(1, 0, 0, preRelease: "123") }
        assertEqual("1.0.0-ABC.123") { try Version(1, 0, 0, preRelease: "ABC.123") }
        assertEqual("1.0.0-123.ABC") { try Version(1, 0, 0, preRelease: "123.ABC") }
        assertEqual("1.0.0-ABC.-") { try Version(1, 0, 0, preRelease: "ABC.-") }

        assertEqual("1.0.0-ABC+ABC") { try Version(1, 0, 0, preRelease: "ABC", build: "ABC") }
        assertEqual("1.0.0-123+123") { try Version(1, 0, 0, preRelease: "123", build: "123") }
        assertEqual("1.0.0-ABC.123+ABC.123") { try Version(1, 0, 0, preRelease: "ABC.123", build: "ABC.123") }
        assertEqual("1.0.0-123.ABC+123.ABC") { try Version(1, 0, 0, preRelease: "123.ABC", build: "123.ABC") }
        assertEqual("1.0.0-ABC.-+ABC.-") { try Version(1, 0, 0, preRelease: "ABC.-", build: "ABC.-") }
    }

    func test3_testVersionsComparisonInAscendingOrder() {
        let comparisonChain = makeComparisonAscendingChain()
        testChain(comparisonChain, using: <)
    }

    func test4_testVersionsComparisonInDescendingOrder() {
        let comparisonChain = makeComparisonDescendingChain()
        testChain(comparisonChain, using: >)
    }
}

private func assertInitializingErrorEqual(to versionError: VersionParsingError, for version: () throws -> Version) {
    XCTAssertThrowsError(try version()) { error in
        let error = error as? VersionParsingError
        XCTAssertNotNil(error)
        XCTAssertEqual(error, versionError)
    }
}

private func assertInitializingErrorEqual(to versionError: VersionParsingError, for versionString: String) {
    assertInitializingErrorEqual(to: versionError, for: { try Version(versionString) })
}

private func assertEqual(_ lhs: String, _ rhs: () throws -> Version) {
    let lhs = try? Version(lhs)
    let rhs = try? rhs()

    XCTAssertNotNil(lhs)
    XCTAssertNotNil(rhs)
    XCTAssertEqual(lhs, rhs)
}

private func makeComparisonAscendingChain() -> [String] {
    [
        "1.0.0-alpha",
        "1.0.0-alpha.1",
        "1.0.0-alpha.beta",
        "1.0.0-beta",
        "1.0.0-beta.2",
        "1.0.0-beta.11",
        "1.0.0-rc.1",
        "1.0.0"
    ]
}

private func makeComparisonDescendingChain() -> [String] {
    makeComparisonAscendingChain().reversed()
}

private func testChain(_ chain: [String], using comparisonRule: (Version, Version) -> Bool) {
    var versionsChain = [Version]()
    for rawVersion in chain {
        guard let version = try? Version(rawVersion) else {
            XCTFail()
            continue
        }

        versionsChain.append(version)
    }

    guard versionsChain.isNotEmpty else {
        XCTFail()
        return
    }

    for index in 0..<versionsChain.count - 1 {
        let lhs = versionsChain[index]
        let rhs = versionsChain[index + 1]

        XCTAssertTrue(comparisonRule(lhs, rhs))
    }
}
