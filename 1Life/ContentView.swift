import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query private var nutritionGoals: [NutritionGoal]

    @State private var appViewModel = AppViewModel()
    @State private var bannerCenter = GlobalBannerCenter.shared

    var body: some View {
        Group {
            if let s = settings.first {
                if s.hasCompletedOnboarding {
                    mainTabView
                } else {
                    OnboardingView(settings: s)
                }
            } else {
                FamilyUI.pageBackground
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(settings.first?.appearance.colorScheme)
        .appSwitchStyle()
        .dismissKeyboardOnTap()
        .overlay(alignment: .top) {
            if let banner = bannerCenter.currentBanner {
                AppErrorBanner(title: banner.title, message: banner.message, tone: banner.tone) {
                    bannerCenter.dismiss()
                }
            }
        }
        .onAppear {
            Task { @MainActor in
                do {
                    SeedData.installDefaultsIfNeeded(settings: settings, context: modelContext)
                    SeedData.installDefaultNutritionGoalIfNeeded(goals: nutritionGoals, context: modelContext)

                    // 保存初始数据
                    try modelContext.save()

                    // 注册通知处理器
                    NotificationManager.shared.registerNavigationHandler { tab in
                        appViewModel.selectedTab = tab
                    }
                    NotificationManager.shared.rescheduleRemindersIfNeeded(settings: settings.first)
                    if let currentSettings = settings.first {
                        FeedbackPreferences.shared.apply(settings: currentSettings)
                    }
                } catch {
                    assertionFailure("Error in ContentView.onAppear: \(error.localizedDescription)")
                }
            }
        }
    }

    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appViewModel.selectedTab {
                case .dashboard:
                    DashboardView()
                case .food:
                    FoodTimelineView()
                case .ai:
                    AIChatView(onOpenSettings: { appViewModel.navigateToAISettings() })
                case .myLife:
                    MyLifeView()
                case .settings:
                    SettingsView()
                }
            }
            .environment(appViewModel)
            .padding(.bottom, 60)

            AppTabBar(selectedTab: $appViewModel.selectedTab)
        }
        .background(FamilyUI.pageBackground)
        .environment(appViewModel)
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    HapticEngine.tap()
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(height: 17)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(selectedTab == tab ? FamilyUI.accent : FamilyUI.panelMutedBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                            .stroke(selectedTab == tab ? Color.black.opacity(0.18) : FamilyUI.panelBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(FamilyUI.panelBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(FamilyUI.panelBorder)
                        .frame(height: 1)
                }
        )
    }
}

struct DaySelectorView: View {
    @Binding var selectedDate: Date
    @State private var isShowingDatePicker = false

    private var isToday: Bool {
        selectedDate.isToday
    }

    var body: some View {
        HStack {
            Button {
                HapticEngine.tap()
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                dayControlIcon("chevron.left")
            }

            Spacer()

            Button {
                isShowingDatePicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(selectedDate.dayDisplay)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(selectedDate.isToday ? "TODAY" : "ARCHIVE")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .sheet(isPresented: $isShowingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate, isPresented: $isShowingDatePicker)
                    .presentationDetents([.height(340)])
                    .presentationDragIndicator(.visible)
            }

            Spacer()

            Button {
                HapticEngine.tap()
                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                    selectedDate = min(next, Date.now)
                }
            } label: {
                dayControlIcon("chevron.right", disabled: isToday)
            }
            .disabled(isToday)
        }
        .padding(.horizontal, 2)
        .frame(minHeight: 40)
    }

    private func dayControlIcon(_ name: String, disabled: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
            .fill(FamilyUI.panelMutedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: FamilyUI.controlCornerRadius)
                    .stroke(FamilyUI.panelBorder, lineWidth: 1)
            )
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(disabled ? Color(.systemGray3) : .primary)
            )
    }
}

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            DatePicker(
                "选择日期",
                selection: $selectedDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
