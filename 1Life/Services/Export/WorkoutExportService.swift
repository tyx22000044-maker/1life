import Foundation

nonisolated enum WorkoutExportService {
    static func exportCSV(_ workouts: [WorkoutLog]) -> String {
        var rows = [csvRow(["日期", "训练类型", "开始时间", "时长分钟", "消耗kcal", "强度", "休息日", "来源", "平均心率", "距离米", "外部标识", "备注"])]
        let formatter = ISO8601DateFormatter()
        for workout in workouts.sorted(by: { $0.startDate < $1.startDate }) {
            rows.append(csvRow([
                formatter.string(from: workout.startDate),
                workout.workoutTypeRaw,
                formatter.string(from: workout.startDate),
                number(workout.durationMinutes),
                workout.caloriesBurned.map(number) ?? "",
                workout.intensityRaw,
                workout.isRestDay ? "是" : "否",
                workout.sourceRaw,
                workout.averageHeartRate.map(number) ?? "",
                workout.distanceMeters.map(number) ?? "",
                workout.externalIdentifier ?? "",
                workout.note
            ]))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    static func exportJSON(_ workouts: [WorkoutLog]) throws -> Data {
        let file = WorkoutBackupFile(
            version: LibraryFileFormat.supportedVersion,
            exportedAt: .now,
            workouts: workouts.sorted(by: { $0.startDate < $1.startDate }).map { WorkoutBackupRecord($0) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    private static func csvRow(_ values: [String]) -> String {
        values.map { value in
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }.joined(separator: ",")
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

nonisolated private struct WorkoutBackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let workouts: [WorkoutBackupRecord]
}

nonisolated private struct WorkoutBackupRecord: Codable {
    let id: UUID
    let workoutType: String
    let startDate: Date
    let durationMinutes: Double
    let caloriesBurned: Double?
    let intensity: String
    let isRestDay: Bool
    let source: String
    let externalIdentifier: String?
    let note: String
    let averageHeartRate: Double?
    let distanceMeters: Double?
    let createdAt: Date
    let updatedAt: Date

    init(_ workout: WorkoutLog) {
        id = workout.id
        workoutType = workout.workoutTypeRaw
        startDate = workout.startDate
        durationMinutes = workout.durationMinutes
        caloriesBurned = workout.caloriesBurned
        intensity = workout.intensityRaw
        isRestDay = workout.isRestDay
        source = workout.sourceRaw
        externalIdentifier = workout.externalIdentifier
        note = workout.note
        averageHeartRate = workout.averageHeartRate
        distanceMeters = workout.distanceMeters
        createdAt = workout.createdAt
        updatedAt = workout.updatedAt
    }
}
