import Foundation

struct DailyHistoryDraft: Identifiable {
    let id = UUID()
    var date: Date
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fibre: Double
    var weight: Double?
}

enum DailyHistoryImportParser {
    static func parse(_ text: String, calendar: Calendar = .current) -> [DailyHistoryDraft] {
        let lines = text
            .split(whereSeparator: \ .isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var draftsByDay: [Date: DailyHistoryDraft] = [:]
        var orderedDays: [Date] = []
        var currentDate: Date?
        var currentYear: Int?
        var block: [String] = []
        var pendingStartingWeight: Double?

        func appendDraft(_ draft: DailyHistoryDraft) {
            let day = calendar.startOfDay(for: draft.date)
            if var existing = draftsByDay[day] {
                if draft.calories > 0 { existing.calories = draft.calories }
                if draft.protein > 0 { existing.protein = draft.protein }
                if draft.carbs > 0 { existing.carbs = draft.carbs }
                if draft.fat > 0 { existing.fat = draft.fat }
                if draft.fibre > 0 { existing.fibre = draft.fibre }
                if let weight = draft.weight { existing.weight = weight }
                draftsByDay[day] = existing
            } else {
                draftsByDay[day] = draft
                orderedDays.append(day)
            }
        }

        func flushBlock() {
            guard let currentDate else { return }
            if let draft = parseBlock(date: currentDate, lines: block, calendar: calendar) {
                appendDraft(draft)
            }
            block.removeAll()
        }

        for line in lines {
            if line.localizedCaseInsensitiveContains("starting weight") {
                pendingStartingWeight = weightValue(in: line)
                continue
            }

            if isDateRangeLine(line) {
                flushBlock()
                currentDate = nil
                continue
            }

            if let match = dateMatch(in: line, fallbackYear: currentYear, calendar: calendar) {
                flushBlock()
                currentDate = match.date
                currentYear = calendar.component(.year, from: match.date)

                if let startingWeight = pendingStartingWeight {
                    block.append("Weight: \(startingWeight)kg")
                    pendingStartingWeight = nil
                }

                let remainder = String(line[..<match.range.lowerBound] + line[match.range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let weight = weightValue(in: remainder) {
                    block.append("Weight: \(weight)kg")
                } else if !remainder.isEmpty {
                    block.append(remainder)
                }
            } else {
                block.append(line)
            }
        }

        flushBlock()
        return orderedDays.compactMap { draftsByDay[$0] }
    }

    private static func parseBlock(date: Date, lines: [String], calendar: Calendar) -> DailyHistoryDraft? {
        var calories: Int?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var fibre: Double?
        var weight: Double?
        var positionalValues: [Double] = []

        for line in lines {
            let lowercased = line.lowercased()

            if lowercased.contains("unknown") {
                continue
            } else if lowercased.contains("cal") || lowercased.contains("kcal") {
                if let value = nutritionValue(in: line) {
                    calories = Int(value.rounded())
                }
            } else if lowercased.contains("protein") {
                protein = nutritionValue(in: line)
            } else if lowercased.contains("carb") {
                carbs = nutritionValue(in: line)
            } else if lowercased.contains("fat") {
                fat = nutritionValue(in: line)
            } else if lowercased.contains("fibre") || lowercased.contains("fiber") {
                fibre = nutritionValue(in: line)
            } else if lowercased.contains("weigh") || lowercased.contains("weight") || lowercased.contains("kg") || lowercased.contains("lb") {
                weight = weightValue(in: line)
            } else if let value = nutritionValue(in: line) {
                positionalValues.append(value)
            }
        }

        if calories == nil, positionalValues.indices.contains(0) { calories = Int(positionalValues[0].rounded()) }
        if protein == nil, positionalValues.indices.contains(1) { protein = positionalValues[1] }
        if carbs == nil, positionalValues.indices.contains(2) { carbs = positionalValues[2] }
        if fat == nil, positionalValues.indices.contains(3) { fat = positionalValues[3] }
        if fibre == nil, positionalValues.indices.contains(4) { fibre = positionalValues[4] }

        guard calories != nil || protein != nil || carbs != nil || fat != nil || fibre != nil || weight != nil else {
            return nil
        }

        return DailyHistoryDraft(
            date: calendar.startOfDay(for: date),
            calories: max(calories ?? 0, 0),
            protein: max(protein ?? 0, 0),
            carbs: max(carbs ?? 0, 0),
            fat: max(fat ?? 0, 0),
            fibre: max(fibre ?? 0, 0),
            weight: weight
        )
    }

    private struct DateMatch {
        var date: Date
        var range: Range<String.Index>
    }

    private static func isDateRangeLine(_ text: String) -> Bool {
        let monthPattern = "January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec"
        let pattern = "\\b(?:\(monthPattern))\\s+\\d{1,2}(?:st|nd|rd|th)?\\s*[-–—]\\s*\\d{1,2}(?:st|nd|rd|th)?\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func dateMatch(in text: String, fallbackYear: Int?, calendar: Calendar) -> DateMatch? {
        let monthPattern = "January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec"
        let patterns = [
            "\\b(?:\(monthPattern))\\s+\\d{1,2}(?:st|nd|rd|th)?(?:,\\s*|\\s+)\\d{4}\\b",
            "\\b(?:\(monthPattern))\\s+\\d{1,2}(?:st|nd|rd|th)?\\b"
        ]

        for pattern in patterns {
            guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            let rawDate = String(text[range])
            if let date = parseDate(rawDate, fallbackYear: fallbackYear, calendar: calendar) {
                return DateMatch(date: date, range: range)
            }
        }

        return nil
    }

    private static func parseDate(_ text: String, fallbackYear: Int?, calendar: Calendar) -> Date? {
        let cleaned = text
            .replacingOccurrences(of: #"(\d{1,2})(st|nd|rd|th)\b"#, with: "$1", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: #"\bSept\b"#, with: "Sep", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let hasYear = cleaned.range(of: #"\b\d{4}\b"#, options: .regularExpression) != nil
        let candidate = hasYear ? cleaned : "\(cleaned) \(fallbackYear ?? calendar.component(.year, from: .now))"
        let formats = ["MMMM d yyyy", "MMM d yyyy"]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: candidate) {
                return calendar.startOfDay(for: date)
            }
        }
        return nil
    }

    private static func nutritionValue(in text: String) -> Double? {
        let normalized = normalizedNumberText(text)
        let rangePattern = #"(-?\d+(?:\.\d+)?)\s*[-–—]\s*(-?\d+(?:\.\d+)?)"#
        if let range = normalized.range(of: rangePattern, options: .regularExpression) {
            let match = String(normalized[range])
            let values = numbers(in: match)
            if values.count >= 2 {
                return (values[0] + values[1]) / 2
            }
        }
        return numbers(in: normalized).first
    }

    private static func weightValue(in text: String) -> Double? {
        let lowercased = text.lowercased()
        guard lowercased.contains("weigh") || lowercased.contains("weight") || lowercased.contains("kg") || lowercased.contains("lb") else {
            return nil
        }

        let withoutDates = removeDateFragments(from: text)
        let values = numbers(in: normalizedNumberText(withoutDates))
        return values.last
    }

    private static func removeDateFragments(from text: String) -> String {
        let monthPattern = "January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec"
        let patterns = [
            "\\b(?:\(monthPattern))\\s+\\d{1,2}(?:st|nd|rd|th)?(?:,\\s*|\\s+)\\d{4}\\b",
            "\\b(?:\(monthPattern))\\s+\\d{1,2}(?:st|nd|rd|th)?\\b"
        ]

        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
    }

    private static func normalizedNumberText(_ text: String) -> String {
        text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "~", with: "")
    }

    private static func numbers(in text: String) -> [Double] {
        let pattern = #"-?\d+(?:\.\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return Double(text[range])
        }
    }
}
