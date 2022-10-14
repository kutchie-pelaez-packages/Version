import CoreUtils

@propertyWrapper public struct NullableVersionUserDefault {
    @UserDefault private var versionDescription: String?

    public var wrappedValue: Version? {
        get {
            guard let versionDescription else { return nil }

            return try? Version(versionDescription)
        }
        set { versionDescription = newValue?.description }
    }

    public init(domain: String, name: String) {
        self._versionDescription = UserDefault(domain: domain, name: name)
    }
}
