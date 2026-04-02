import Foundation

enum CompilationToggleState: Equatable {
    case off
    case on
    case mixed
}

enum CompilationTag {
    static let storedValue = "1"
    private static let truthyValues: Set<String> = ["1", "t", "true", "on", "y", "yes"]

    static func isEnabled(_ rawValue: String?) -> Bool {
        let trimmedValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return truthyValues.contains(trimmedValue.lowercased())
    }

    static func normalizedValue(_ rawValue: String?) -> String? {
        isEnabled(rawValue) ? storedValue : nil
    }

    static func setEnabled(_ isEnabled: Bool, in tags: inout [String: String]) {
        if isEnabled {
            tags[TagKey.compilation] = storedValue
        } else {
            tags.removeValue(forKey: TagKey.compilation)
        }
    }
}
