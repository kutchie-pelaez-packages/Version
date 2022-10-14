import CoreUtils

@propertyWrapper public struct VersionUserDefault {
    @UserDefault private var versionDescription: String?
    private let defaultValue: Version

    public var wrappedValue: Version {
        get {
            guard
                let versionDescription,
                let version = try? Version(versionDescription)
            else {
                return defaultValue
            }

            return version
        }
        set { versionDescription = newValue.description }
    }

    public init(domain: String, name: String, defaultValue: Version) {
        self._versionDescription = UserDefault(domain: domain, name: name)
        self.defaultValue = defaultValue
    }

    public init(domain: String, name: String, defaultValue: String) {
        guard let defaultValue = try? Version(defaultValue) else {
            fatalError()
        }

        self.init(domain: domain, name: name, defaultValue: defaultValue)
    }
}
