import SwiftUI
import SwiftData

@main
struct OneLifeApp: App {
    @State private var showSplash = true
    private let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema(versionedSchema: SettingsSchemaV2.self)
            modelContainer = try ModelContainer(for: schema, migrationPlan: SettingsMigrationPlan.self)
            // 配置自动保存和合并策略
            modelContainer.mainContext.autosaveEnabled = true
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
        AppTypography.configureGlobalAppearance()
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
