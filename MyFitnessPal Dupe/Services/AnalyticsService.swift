import Foundation

struct AnalyticsPeriodSummary: Identifiable, Equatable {
    let id: Int
    let dayCount: Int
    let startDate: Date
    let endDate: Date
    let trackedDays: Int
    let averageCalories: Int
    let averageProtein: Double
    let averageCarbs: Double
    let averageFat: Double
    let averageFibre: Double
    let daysAtOrUnderGoal: Int
    let weightChange: Double?
    let firstWeight: Double?
    let latestWeight: Double?
    let highestCalorieDay: DailyAnalyticsPoint?
    let lowestCalorieDay: DailyAnalyticsPoint?

    var dateRangeText: String {
        "\(startDate.formatted(.dateTime.day().month(.abbreviated))) - \(endDate.formatted(.dateTime.day().month(.abbreviated)))"
    }
}

struct DailyAnalyticsPoint: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fibre: Double
    let weight: Double?
    let source: Source

    enum Source: Equatable {
        case foodLog
        case importedHistory
    }
}

struct AnalyticsSnapshot: Equatable {
    let generatedAt: Date
    let summaries: [AnalyticsPeriodSummary]

    var primarySummary: AnalyticsPeriodSummary? {
        summaries.first { $0.dayCount == 14 } ?? summaries.first
    }

    var contextText: String {
        guard !summaries.isEmpty else {
            return "No analytics are available yet."
        }

        let lines = summaries.map { summary in
            var parts = [
                "Last \(summary.dayCount) days (\(summary.dateRangeText)):",
                "- Tracked days: \(summary.trackedDays)/\(summary.dayCount)",
                "- Average calories: \(summary.averageCalories) kcal",
                "- Average protein: \(format(summary.averageProtein))g",
                "- Average carbs: \(format(summary.averageCarbs))g",
                "- Average fat: \(format(summary.averageFat))g",
                "- Average fibre: \(format(summary.averageFibre))g",
                "- Days at or under calorie goal: \(summary.daysAtOrUnderGoal)"
            ]

            if let firstWeight = summary.firstWeight, let latestWeight = summary.latestWeight, let weightChange = summary.weightChange {
                parts.append("- Weight: \(format(firstWeight))kg to \(format(latestWeight))kg, change \(signed(weightChange))kg")
            } else {
                parts.append("- Weight change: not enough weigh-ins")
            }

            if let highest = summary.highestCalorieDay {
                parts.append("- Highest calorie day: \(highest.date.formatted(date: .abbreviated, time: .omitted)), \(highest.calories) kcal")
            }

            if let lowest = summary.lowestCalorieDay {
                parts.append("- Lowest calorie day: \(lowest.date.formatted(date: .abbreviated, time: .omitted)), \(lowest.calories) kcal")
            }

            return parts.joined(separator: "\n")
        }

        return lines.joined(separator: "\n\n")
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func signed(_ value: Double) -> String {
        let formatted = format(value)
        return value > 0 ? "+\(formatted)" : formatted
    }
}

enum AnalyticsService {
    static func snapshot(
        entries: [FoodEntry],
        historyEntries: [DailyHistoryEntry],
        goals: DailyGoals?,
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> AnalyticsSnapshot {
        let points = dailyPoints(entries: entries, historyEntries: historyEntries, calendar: calendar)
        let latestDate = points.last?.date ?? calendar.startOfDay(for: referenceDate)
        let summaries = [7, 14].map { dayCount in
            summary(dayCount: dayCount, endingOn: latestDate, points: points, goals: goals, calendar: calendar)
        }
        return AnalyticsSnapshot(generatedAt: referenceDate, summaries: summaries)
    }

    private static func dailyPoints(entries: [FoodEntry], historyEntries: [DailyHistoryEntry], calendar: Calendar) -> [DailyAnalyticsPoint] {
        let entriesByDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let historyByDay = Dictionary(uniqueKeysWithValues: historyEntries.map { (calendar.startOfDay(for: $0.date), $0) })
        let days = Set(entriesByDay.keys).union(historyByDay.keys).sorted()

        return days.compactMap { day in
            let dayEntries = entriesByDay[day] ?? []
            if !dayEntries.isEmpty {
                let totals = NutritionCalculator.totals(for: dayEntries)
                return DailyAnalyticsPoint(
                    date: day,
                    calories: totals.calories,
                    protein: totals.protein,
                    carbs: totals.carbs,
                    fat: totals.fat,
                    fibre: totals.fibre,
                    weight: historyByDay[day]?.weight,
                    source: .foodLog
                )
            }

            guard let history = historyByDay[day] else { return nil }
            return DailyAnalyticsPoint(
                date: day,
                calories: history.calories,
                protein: history.protein,
                carbs: history.carbs,
                fat: history.fat,
                fibre: history.fibre,
                weight: history.weight,
                source: .importedHistory
            )
        }
    }

    private static func summary(
        dayCount: Int,
        endingOn endDate: Date,
        points: [DailyAnalyticsPoint],
        goals: DailyGoals?,
        calendar: Calendar
    ) -> AnalyticsPeriodSummary {
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate) ?? endDate
        let periodPoints = points.filter { $0.date >= startDate && $0.date <= endDate }
        let trackedDays = periodPoints.count
        let divisor = max(trackedDays, 1)
        let calorieGoal = goals?.calories ?? 0
        let weightPoints = periodPoints.filter { $0.weight != nil }
        let firstWeight = weightPoints.first?.weight
        let latestWeight = weightPoints.last?.weight
        let weightChange = firstWeight.flatMap { first in latestWeight.map { $0 - first } }

        return AnalyticsPeriodSummary(
            id: dayCount,
            dayCount: dayCount,
            startDate: startDate,
            endDate: endDate,
            trackedDays: trackedDays,
            averageCalories: periodPoints.reduce(0) { $0 + $1.calories } / divisor,
            averageProtein: periodPoints.reduce(0) { $0 + $1.protein } / Double(divisor),
            averageCarbs: periodPoints.reduce(0) { $0 + $1.carbs } / Double(divisor),
            averageFat: periodPoints.reduce(0) { $0 + $1.fat } / Double(divisor),
            averageFibre: periodPoints.reduce(0) { $0 + $1.fibre } / Double(divisor),
            daysAtOrUnderGoal: calorieGoal > 0 ? periodPoints.filter { $0.calories <= calorieGoal }.count : 0,
            weightChange: weightChange,
            firstWeight: firstWeight,
            latestWeight: latestWeight,
            highestCalorieDay: periodPoints.max { $0.calories < $1.calories },
            lowestCalorieDay: periodPoints.min { $0.calories < $1.calories }
        )
    }
}
