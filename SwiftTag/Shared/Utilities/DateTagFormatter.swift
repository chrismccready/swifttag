import Foundation

enum DateTagFormatter {
    private static let locale = Locale(identifier: "en_US_POSIX")
    private static let editableTextFormats = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy-MM", "yyyy"]
        return parse(value, formats: formats)
    }

    static func tagText(_ value: String?, defaultDate: Date) -> String {
        guard let value else {
            return format(defaultDate)
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return format(defaultDate)
        }

        if let editableTextFormat = editableTextFormat(for: trimmedValue),
           parse(trimmedValue, formats: [editableTextFormat]) != nil {
            return trimmedValue
        }

        if let parsedDate = parse(trimmedValue) {
            return format(parsedDate)
        }

        return format(defaultDate)
    }

    private static func parse(_ value: String, formats: [String]) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.isLenient = false

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func editableTextFormat(for value: String) -> String? {
        editableTextFormats.first { format in
            switch format {
            case "yyyy-MM-dd":
                value.count == 10 &&
                    value[value.index(value.startIndex, offsetBy: 4)] == "-" &&
                    value[value.index(value.startIndex, offsetBy: 7)] == "-" &&
                    value.enumerated().allSatisfy { index, character in
                        index == 4 || index == 7 ? character == "-" : character.isNumber
                    }
            case "yyyy-MM":
                value.count == 7 &&
                    value[value.index(value.startIndex, offsetBy: 4)] == "-" &&
                    value.enumerated().allSatisfy { index, character in
                        index == 4 ? character == "-" : character.isNumber
                    }
            case "yyyy":
                value.count == 4 && value.allSatisfy(\.isNumber)
            default:
                false
            }
        }
    }
}
