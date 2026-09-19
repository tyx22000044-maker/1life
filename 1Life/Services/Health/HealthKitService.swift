import Foundation
import HealthKit

struct HealthEnergySummary {
    var date: Date
    var activeEnergyKcal: Double
    var basalEnergyKcal: Double?
    var estimatedBMRKcal: Double?

    var restingEnergyKcal: Double? {
        basalEnergyKcal ?? estimatedBMRKcal
    }

    var tdeeKcal: Double? {
        guard let restingEnergyKcal else { return nil }
        return restingEnergyKcal + activeEnergyKcal
    }

    var usesEstimatedBMR: Bool {
        basalEnergyKcal == nil && estimatedBMRKcal != nil
    }
}

struct HealthActivitySummary {
    var date: Date
    var stepCount: Double
    var activeEnergyKcal: Double
}

struct HealthBodyMeasurementSnapshot {
    var date: Date
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var heightCm: Double?
}

enum HealthKitServiceError: LocalizedError {
    case unavailable
    case unsupportedType

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前设备不支持 Apple Health。"
        case .unsupportedType:
            return "无法读取所需的健康数据类型。"
        }
    }
}

extension Notification.Name {
    static let healthEnergyDidUpdate = Notification.Name("healthEnergyDidUpdate")
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var activeEnergyBackgroundObserver: HKObserverQuery?

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Registers the hourly active-energy observer. Callers must only invoke this once the
    /// user has turned Apple Health on: registering it at launch asked for background
    /// delivery from people who never connected HealthKit.
    func enableEnergyBackgroundDelivery() {
        guard isAvailable,
              let activeType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        store.enableBackgroundDelivery(for: activeType, frequency: .hourly) { _, _ in }

        let query = HKObserverQuery(sampleType: activeType, predicate: nil) { [weak self] _, _, error in
            guard error == nil, self != nil else { return }
            Task { @MainActor in
                NotificationCenter.default.post(name: .healthEnergyDidUpdate, object: nil)
            }
        }
        activeEnergyBackgroundObserver = query
        store.execute(query)
    }

    /// Stops the observer and background delivery, e.g. after the user disconnects HealthKit.
    func disableEnergyBackgroundDelivery() {
        guard isAvailable,
              let activeType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        if let query = activeEnergyBackgroundObserver {
            store.stop(query)
            activeEnergyBackgroundObserver = nil
        }
        store.disableBackgroundDelivery(for: activeType) { _, _ in }
    }

    /// Energy and body metrics: everything the TDEE and body-record features need.
    /// Sleep, workouts, heart rate, distance and daylight are requested separately, by the
    /// screens that actually show them, so connecting Apple Health never asks for the
    /// whole set at once. `Settings → Apple Health` lists the purpose of each group.
    func requestAuthorization(needsWriteAccess: Bool = false) async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        guard let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalEnergy = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
              let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
              let height = HKObjectType.quantityType(forIdentifier: .height),
              let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitServiceError.unsupportedType
        }

        let readTypes: Set<HKObjectType> = [activeEnergy, basalEnergy, bodyMass, bodyFat, height, stepCount]
        let shareTypes: Set<HKSampleType> = needsWriteAccess ? [bodyMass, bodyFat] : []
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Additional read types for the training timeline and the Dashboard health metrics.
    /// A rejection here must not disable the core energy/step features.
    func requestActivityDetailAuthorization() async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRate)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            readTypes.insert(distance)
        }
        if let daylight = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
            readTypes.insert(daylight)
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func energySummary(for date: Date, settings: UserSettings?) async throws -> HealthEnergySummary {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        let activeEnergy = try await quantitySum(identifier: .activeEnergyBurned, unit: .kilocalorie(), date: date)
        let basalEnergy = try await quantitySum(identifier: .basalEnergyBurned, unit: .kilocalorie(), date: date)

        return HealthEnergySummary(
            date: date,
            activeEnergyKcal: activeEnergy ?? 0,
            basalEnergyKcal: basalEnergy,
            estimatedBMRKcal: settings?.estimatedBMR
        )
    }

    func activitySummary(for date: Date) async throws -> HealthActivitySummary {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        return HealthActivitySummary(
            date: date,
            stepCount: try await quantitySum(identifier: .stepCount, unit: .count(), date: date) ?? 0,
            activeEnergyKcal: try await quantitySum(identifier: .activeEnergyBurned, unit: .kilocalorie(), date: date) ?? 0
        )
    }

    func workoutLogs(for date: Date) async throws -> [WorkoutLog] {
        guard isAvailable else { throw HealthKitServiceError.unavailable }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKWorkout] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        return samples.map { sample in
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)
            let avgHR = heartRateType.flatMap {
                sample.statistics(for: $0)?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            }
            let distanceMeters = sample.totalDistance?.doubleValue(for: .meter())
            return WorkoutLog(
                workoutType: workoutType(for: sample.workoutActivityType),
                startDate: sample.startDate,
                durationMinutes: max(sample.duration / 60, 1),
                caloriesBurned: sample.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                intensity: .moderate,
                isRestDay: false,
                source: .healthKit,
                externalIdentifier: sample.uuid.uuidString,
                note: "由 Apple Health 导入",
                averageHeartRate: avgHR,
                distanceMeters: distanceMeters
            )
        }
    }

    /// The night the user means when they ask about sleep on `date`: bedtime the
    /// previous evening through late the next morning, not a raw 24-hour block.
    nonisolated static func sleepWindow(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: date)
        let previousEvening = calendar.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
        let nextNoon = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
        return (previousEvening, nextNoon)
    }

    /// Clips samples to the night window and merges overlaps before summing.
    /// Staged sleep samples overlap each other, and multiple sources can report the
    /// same period, so a naive sum double-counts the night.
    nonisolated static func sleepSeconds(in window: (start: Date, end: Date), samples: [(start: Date, end: Date)]) -> Double {
        let clipped: [(start: Date, end: Date)] = samples.compactMap { sample in
            let start = max(sample.start, window.start)
            let end = min(sample.end, window.end)
            guard end > start else { return nil }
            return (start, end)
        }
        let sorted = clipped.sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var runningStart: Date?
        var runningEnd: Date?
        for interval in sorted {
            if let current = runningEnd, interval.start <= current {
                runningEnd = max(current, interval.end)
            } else {
                if let start = runningStart, let end = runningEnd {
                    total += end.timeIntervalSince(start)
                }
                runningStart = interval.start
                runningEnd = interval.end
            }
        }
        if let start = runningStart, let end = runningEnd {
            total += end.timeIntervalSince(start)
        }
        return total
    }

    func sleepHours(for date: Date) async throws -> Double? {
        guard isAvailable else { return nil }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let window = Self.sleepWindow(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let intervals = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) }
                let totalSeconds = Self.sleepSeconds(in: window, samples: intervals)
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    func daylightMinutes(for date: Date) async throws -> Double? {
        guard isAvailable else { return nil }
        return try await quantitySum(identifier: .timeInDaylight, unit: .minute(), date: date)
    }

    func latestBodyMeasurement() async throws -> HealthBodyMeasurementSnapshot? {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        let weightSample = try await latestQuantitySample(identifier: .bodyMass)
        let bodyFatSample = try await latestQuantitySample(identifier: .bodyFatPercentage)
        let heightSample = try await latestQuantitySample(identifier: .height)

        guard weightSample != nil || bodyFatSample != nil || heightSample != nil else { return nil }
        let date = [
            weightSample?.startDate,
            bodyFatSample?.startDate,
            heightSample?.startDate
        ].compactMap { $0 }.max() ?? .now
        let bodyFatPercentage = bodyFatSample.map { sample in
            sample.quantity.doubleValue(for: .percent()) * 100
        }

        return HealthBodyMeasurementSnapshot(
            date: date,
            weightKg: weightSample?.quantity.doubleValue(for: .gramUnit(with: .kilo)),
            bodyFatPercentage: bodyFatPercentage,
            heightCm: heightSample?.quantity.doubleValue(for: .meterUnit(with: .centi))
        )
    }

    func saveBodyMeasurement(weightKg: Double?, bodyFatPercentage: Double?, date: Date) async throws {
        guard isAvailable else { throw HealthKitServiceError.unavailable }
        var samples: [HKQuantitySample] = []

        if let weightKg, let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
            samples.append(HKQuantitySample(type: bodyMass, quantity: quantity, start: date, end: date))
        }
        if let bodyFatPercentage, let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            let quantity = HKQuantity(unit: .percent(), doubleValue: bodyFatPercentage / 100)
            samples.append(HKQuantitySample(type: bodyFat, quantity: quantity, start: date, end: date))
        }

        guard !samples.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: HealthKitServiceError.unsupportedType)
                }
            }
        }
    }

    private func quantitySum(identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.unsupportedType
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double?, Error>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = result?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func latestQuantitySample(identifier: HKQuantityTypeIdentifier) async throws -> HKQuantitySample? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.unsupportedType
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
    }

    private func workoutType(for activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .strength
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .walking:
            return .walking
        case .yoga, .pilates:
            return .yoga
        case .highIntensityIntervalTraining:
            return .hiit
        case .basketball, .soccer, .tennis, .badminton, .tableTennis, .volleyball:
            return .ballSports
        default:
            return .other
        }
    }
}
