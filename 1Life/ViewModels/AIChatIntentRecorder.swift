import Foundation
import SwiftData

struct AIChatRecordedIntent {
    let assistantMessage: String
    let persistReason: String?
    let shouldPlaySuccessHaptic: Bool
}

struct AIChatRecordedBodyMeasurement {
    let record: BodyMeasurement
    let intent: AIChatRecordedIntent
}

@MainActor
struct AIChatIntentRecorder {
    static func recordWater(amount: Double, date: Date, modelContext: ModelContext) -> AIChatRecordedIntent {
        let log = WaterLog(date: date, amount: amount)
        modelContext.insert(log)
        return AIChatRecordedIntent(
            assistantMessage: "已记录饮水 \(Int(amount))ml",
            persistReason: "add water",
            shouldPlaySuccessHaptic: true
        )
    }

    static func recordJournal(
        content: String,
        mood: Mood?,
        tags: [ActivityTag],
        date: Date,
        modelContext: ModelContext
    ) -> AIChatRecordedIntent {
        let entry = JournalEntry(date: date, mood: mood, tags: tags.map(\.rawValue), content: content)
        modelContext.insert(entry)
        let moodText = mood.map { " · \($0.displayName)" } ?? ""
        let tagText = tags.isEmpty ? "" : " · \(tags.map(\.displayName).joined(separator: "、"))"
        return AIChatRecordedIntent(
            assistantMessage: "已记录状态\(moodText)\(tagText)",
            persistReason: "add journal",
            shouldPlaySuccessHaptic: true
        )
    }

    static func recordHabitLog(
        habitName name: String,
        value: Double,
        date: Date,
        modelContext: ModelContext
    ) -> AIChatRecordedIntent {
        let habits = ((try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []).filter { !$0.isArchived }
        guard let habit = habits.first(where: { $0.name.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains($0.name) }) else {
            return AIChatRecordedIntent(
                assistantMessage: "没有找到习惯「\(name)」，可以先在「我的」里创建。",
                persistReason: nil,
                shouldPlaySuccessHaptic: false
            )
        }

        let log = HabitLog(date: date, value: value)
        log.habit = habit
        habit.logs?.append(log)
        modelContext.insert(log)
        return AIChatRecordedIntent(
            assistantMessage: "已记录习惯「\(habit.name)」",
            persistReason: "add habit log",
            shouldPlaySuccessHaptic: true
        )
    }

    static func recordWorkout(
        _ workout: AIParsedWorkout,
        date: Date,
        modelContext: ModelContext
    ) -> AIChatRecordedIntent {
        let log = WorkoutLog(
            workoutType: workout.workoutType,
            startDate: date,
            durationMinutes: workout.durationMinutes,
            caloriesBurned: workout.caloriesBurned,
            intensity: workout.intensity,
            note: workout.note
        )
        modelContext.insert(log)
        return AIChatRecordedIntent(
            assistantMessage: "已记录\(workout.workoutType.displayName) \(Int(workout.durationMinutes)) 分钟",
            persistReason: "add workout",
            shouldPlaySuccessHaptic: true
        )
    }

    static func recordBowelLog(
        _ log: AIParsedBowelLog,
        date: Date,
        modelContext: ModelContext
    ) -> AIChatRecordedIntent {
        let entry = BowelLog(date: date, bristolType: log.bristolType, note: log.note)
        modelContext.insert(entry)
        return AIChatRecordedIntent(
            assistantMessage: "已记录排便：\(log.bristolType.emoji) \(log.bristolType.displayName)",
            persistReason: "add bowel log",
            shouldPlaySuccessHaptic: true
        )
    }

    static func recordBodyMeasurement(
        _ measurement: AIParsedBodyMeasurement,
        date: Date,
        modelContext: ModelContext
    ) -> AIChatRecordedBodyMeasurement {
        let record = BodyMeasurement(
            date: date,
            weightKg: measurement.weightKg,
            bodyFatPercentage: measurement.bodyFatPercentage,
            source: .ai,
            syncedToAppleHealth: false,
            note: measurement.note
        )
        modelContext.insert(record)

        let weightText = measurement.weightKg.map { String(format: "%.1fkg", $0) } ?? ""
        let bodyFatText = measurement.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? ""
        let combined = [weightText, bodyFatText].filter { !$0.isEmpty }.joined(separator: " · ")
        return AIChatRecordedBodyMeasurement(
            record: record,
            intent: AIChatRecordedIntent(
                assistantMessage: "已记录身体数据\(combined.isEmpty ? "" : "：\(combined)")",
                persistReason: "add body measurement",
                shouldPlaySuccessHaptic: true
            )
        )
    }
}
