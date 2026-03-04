import Foundation

enum DateTagFormatter {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy-MM", "yyyy"]
        let formatter = DateFormatter()
        formatter.locale = locale

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
}
