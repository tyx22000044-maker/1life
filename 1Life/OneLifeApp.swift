import SwiftUI
import SwiftData
import os

@main
struct OneLifeApp: App {
    @State private var showSplash = true
    private let modelContainer: ModelContainer

    private static let persistenceLogger = Logger(subsystem: "com.yunxuan.OneLife", category: "persistence")

    /// Written when the on-disk store could not be opened or migrated and the app fell
    /// back to an in-memory database. The UI reads it so the user is not silently left
    /// recording into a store that dies with the process.
    enum AppPersistence {
        static let didFallBackToMemoryStoreKey = "OneLifeDidFallbackToMemoryStore"

        static var didFallBackToMemoryStore: Bool {
            UserDefaults.standard.bool(forKey: didFallBackToMemoryStoreKey)
        }

        static func record(_ didFallBack: Bool) {
            UserDefaults.standard.set(didFallBack, forKey: didFallBackToMemoryStoreKey)
        }
    }

    init() {
        modelContainer = Self.makeModelContainer()
        AppTypography.configureGlobalAppearance()
    }

    /// 建库/迁移失败时不再 fatalError —— 老用户升级遇到迁移失败会「打开即崩」且无法自救。
    /// 改为降级到内存容器并写入标记位，让 App 至少能启动、由界面提示用户。
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SettingsSchemaV2.self)

        do {
            let container = try ModelContainer(for: schema, migrationPlan: SettingsMigrationPlan.self)
            // 配置自动保存和合并策略
            container.mainContext.autosaveEnabled = true
            AppPersistence.record(false)
            return container
        } catch {
            persistenceLogger.error(
                "ModelContainer 创建失败，降级为内存容器: \(error.localizedDescription, privacy: .public)"
            )
            AppPersistence.record(true)

            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [inMemory]) {
                fallback.mainContext.autosaveEnabled = true
                return fallback
            }

            // 连内存容器都无法创建说明环境彻底不可用，此时任何降级都没有意义。
            fatalError("Unable to create any ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .appTypography()

                if showSplash {
                    SplashView(appName: "1Life", iconName: "SplashAppIcon") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .task {
                HealthKitService.shared.enableEnergyBackgroundDelivery()
            }
        }
        .modelContainer(modelContainer)
    }
}
