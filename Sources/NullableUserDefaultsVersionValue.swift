import CoreUtils

@propertyWrapper public struct NullableUserDefaultsVersionValue {
    @UserDefaultsValue private var versionDescription: String?

    public var wrappedValue: Version? {
        get {
            guard let versionDescription else { return nil }

            return try? Version(versionDescription)
        }
        set { versionDescription = newValue?.description }
    }

    public init(domain: String, name: String) {
        self._versionDescription = UserDefaultsValue(domain: domain, name: name)
    }
}
