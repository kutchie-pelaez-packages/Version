import Core
import Foundation

public struct Version: CustomStringConvertible, Comparable, Codable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    fileprivate let preReleaseIdentifiers: [MetadataIdentifier]?
    fileprivate let buildIdentifiers: [MetadataIdentifier]?

    public var preRelease: String? { preReleaseIdentifiers?.description }
    public var build: String? { buildIdentifiers?.description }

    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preReleaseIdentifiers = nil
        self.buildIdentifiers = nil
    }

    public init(_ major: Int, _ minor: Int, _ patch: Int, preRelease: String? = nil, build: String? = nil) throws {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.buildIdentifiers = try buildMetadataIdentifiers(from: build)
        self.preReleaseIdentifiers = try preReleaseMetadataIdentifiers(from: preRelease)
    }

    public init(_ string: String) throws {
        let (rawCore, rawPreRelease, rawBuild) = try versionRawComponents(from: string)
        let (major, minor, patch) = try versionCore(from: rawCore)

        if let rawBuild, rawBuild.isEmpty {
            throw VersionParsingError.emptyBuild
        }

        if let rawPreRelease, rawPreRelease.isEmpty {
            throw VersionParsingError.emptyPreRelease
        }

        try self.init(major, minor, patch, preRelease: rawPreRelease, build: rawBuild)
    }

    // MARK: CustomStringConvertible

    public var description: String {
        let core = "\(major).\(minor).\(patch)"
        let coreAndPreRelease = [core, preRelease]
            .unwrapped()
            .joined(separator: "-")
        let corePreReleaseAndBuild = [coreAndPreRelease, build]
            .unwrapped()
            .joined(separator: "+")

        return corePreReleaseAndBuild
    }

    // MARK: Equtable

    public static func == (lhs: Version, rhs: Version) -> Bool {
        compareTwoVersions(lhs, rhs) == .orderedSame && lhs.buildIdentifiers == rhs.buildIdentifiers
    }

    // MARK: Comparable

    public static func < (lhs: Version, rhs: Version) -> Bool {
        compareTwoVersions(lhs, rhs) == .orderedAscending
    }

    // MARK: Decodable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawVerion = try container.decode(String.self)
        self = try Version(rawVerion)
    }

    // MARK: Encodable

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public enum VersionParsingError: Error, Equatable {
    case invalidCoreFormat(String)
    case invalidPreReleaseMetadataIdentifiers([String])
    case invalidBuildMetadataIdentifiers([String])
    case multipleBuildMetadata([String])
    case emptyPreRelease
    case emptyBuild
}

private enum MetadataType {
    case preRelease
    case build
}

private enum MetadataIdentifier: CustomStringConvertible, Comparable {
    case string(String)
    case numeric(Int)

    fileprivate var isValid: Bool {
        switch self {
        case .string(let stringIdentifier):
            guard let regex = try? Regex<Substring>("[A-Za-z0-9-]+") else { return false }

            let matches = description.matches(of: regex)

            guard
                let firstMatch = matches.first,
                firstMatch.count == stringIdentifier.count
            else {
                return false
            }

            return true

        case .numeric:
            return true
        }
    }

    // MARK: CustomStringConvertible

    var description: String {
        switch self {
        case .string(let stringIdentifier):
            return stringIdentifier

        case .numeric(let numericIdentifier):
            return String(numericIdentifier)
        }
    }

    // MARK: Comparable

    static func < (lhs: MetadataIdentifier, rhs: MetadataIdentifier) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhsStringIdentifier), .string(let rhsStringIdentifier)):
            return lhsStringIdentifier < rhsStringIdentifier

        case (.numeric(let lhsNumericIdentifier), .numeric(let rhsNumericIdentifier)):
            return lhsNumericIdentifier < rhsNumericIdentifier

        case (.string, .numeric):
            return false

        case (.numeric, .string):
            return true
        }
    }
}

private func versionRawComponents(from string: String) throws -> (core: String, preRelease: String?, build: String?) {
    let buildSeparatorBasedSplits = string
        .split(
            separator: "+",
            omittingEmptySubsequences: false
        )
        .map(String.init)

    guard buildSeparatorBasedSplits.count <= 2 else {
        throw VersionParsingError.multipleBuildMetadata(
            buildSeparatorBasedSplits.removingFirst()
        )
    }

    let coreAndPreReleaseRawComponents = coreAndPreReleaseRawComponents(from: buildSeparatorBasedSplits[0])

    return (
        core: coreAndPreReleaseRawComponents.core,
        preRelease: coreAndPreReleaseRawComponents.preRelease,
        build: buildSeparatorBasedSplits[safe: 1]
    )
}

private func coreAndPreReleaseRawComponents(from string: String) -> (core: String, preRelease: String?) {
    let preReleaseSeparatorBasedSplits = string
        .split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        .map(String.init)

    return (
        core: preReleaseSeparatorBasedSplits[0],
        preRelease: preReleaseSeparatorBasedSplits[safe: 1]
    )
}

private func buildMetadataIdentifiers(from rawBuild: String?) throws -> [MetadataIdentifier]? {
    guard let rawBuild else { return nil }

    guard rawBuild.isNotEmpty else {
        throw VersionParsingError.emptyBuild
    }

    return try metadataIdentifiers(from: rawBuild, type: .build)
}

private func preReleaseMetadataIdentifiers(from rawPreRelease: String?) throws -> [MetadataIdentifier]? {
    guard let rawPreRelease else { return nil }

    guard rawPreRelease.isNotEmpty else {
        throw VersionParsingError.emptyPreRelease
    }

    return try metadataIdentifiers(from: rawPreRelease, type: .preRelease)
}

private func metadataIdentifiers(from string: String, type: MetadataType) throws -> [MetadataIdentifier]? {
    let metadataIdentifiers = string
        .split(separator: ".")
        .map(String.init)
        .map { stringIdentifier in
            if let numericIdentifier = Int(stringIdentifier) {
                return MetadataIdentifier.numeric(numericIdentifier)
            } else {
                return MetadataIdentifier.string(stringIdentifier)
            }
        }
    let invalidStringIdentifiers = metadataIdentifiers
        .filter { !$0.isValid }

    guard invalidStringIdentifiers.isEmpty else {
        let errorResolver: ([String]) -> VersionParsingError
        switch type {
        case .preRelease:
            errorResolver = VersionParsingError.invalidPreReleaseMetadataIdentifiers

        case .build:
            errorResolver = VersionParsingError.invalidBuildMetadataIdentifiers
        }

        throw errorResolver(invalidStringIdentifiers.map(\.description))
    }

    return metadataIdentifiers
}

private func versionCore(from string: String) throws -> (major: Int, minor: Int, patch: Int) {
    let rawStringComponents = string
        .split(separator: ".")
        .map(String.init)
    let numericComponents = rawStringComponents
        .compactMap(Int.init)

    guard
        1...3 ~= rawStringComponents.count,
        rawStringComponents.count == numericComponents.count
    else {
        throw VersionParsingError.invalidCoreFormat(string)
    }

    let major = numericComponents[safe: 0] ?? 0
    let minor = numericComponents[safe: 1] ?? 0
    let patch = numericComponents[safe: 2] ?? 0

    return (major: major, minor: minor, patch: patch)
}

private func compareTwoVersions(_ lhs: Version, _ rhs: Version) -> ComparisonResult {
    let versionCoresComparisonResult = compareVersionCores(lhs, rhs: rhs)
    let lhsPreReleaseIdentifiers = lhs.preReleaseIdentifiers
    let rhsPreReleaseIdentifiers = rhs.preReleaseIdentifiers

    guard versionCoresComparisonResult == .orderedSame else {
        return versionCoresComparisonResult
    }

    if let lhsPreReleaseIdentifiers, let rhsPreReleaseIdentifiers {
        let preReleaseIdentifiersComparisonResult = compareMetadataIdentifiers(
            lhsPreReleaseIdentifiers,
            rhsPreReleaseIdentifiers
        )

        if versionCoresComparisonResult == .orderedSame {
            return preReleaseIdentifiersComparisonResult
        } else {
            return versionCoresComparisonResult
        }
    } else if lhsPreReleaseIdentifiers != nil {
        return .orderedAscending
    } else if rhsPreReleaseIdentifiers != nil {
        return .orderedDescending
    } else {
        return .orderedSame
    }
}

private func compareVersionCores(_ lhs: Version, rhs: Version) -> ComparisonResult {
    if lhs.major != rhs.major {
        return lhs.major < rhs.major ? .orderedAscending : .orderedDescending
    } else if lhs.minor != rhs.minor {
        return lhs.minor < rhs.minor ? .orderedAscending : .orderedDescending
    } else if lhs.patch != rhs.patch {
        return lhs.patch < rhs.patch ? .orderedAscending : .orderedDescending
    } else {
        return .orderedSame
    }
}

private func compareMetadataIdentifiers(_ lhs: [MetadataIdentifier], _ rhs: [MetadataIdentifier]) -> ComparisonResult {
    guard lhs != rhs else { return .orderedSame }

    for index in 0..<max(lhs.count, rhs.count) {
        let lhsIdentifier = lhs[safe: index]
        let rhsIdentifier = rhs[safe: index]

        if let lhsIdentifier, let rhsIdentifier {
            guard lhsIdentifier != rhsIdentifier else { continue }

            return lhsIdentifier < rhsIdentifier ? .orderedAscending : .orderedDescending
        } else if lhsIdentifier != nil {
            return .orderedDescending
        } else if rhsIdentifier != nil {
            return .orderedAscending
        }
    }

    fatalError()
}

extension Array where Element == MetadataIdentifier {
    fileprivate var description: String? {
        guard isNotEmpty else { return nil }

        return map(\.description).joined(separator: ".")
    }
}
