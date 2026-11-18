import SwiftData
import SwiftUI
import PagewormCore
import PagewormDesign

@main
struct PagewormApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [UserProfile.self, Book.self, ReadingSessionRecord.self, StreakRecord.self, BlockRecord.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @State private var subscriptions = SubscriptionManager()
    @State private var screenTime = ScreenTimeManager()
    @State private var router = AppRouter()

    var body: some View {
        Group {
            if profiles.first?.onboardingCompleted == true {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .environment(subscriptions)
        .environment(screenTime)
        .environment(router)
        .tint(Color.pwMoss)
        .preferredColorScheme(nil)
        .task {
            _ = Store.profile(context)
            _ = Store.streak(context)
            _ = Store.block(context)
            subscriptions.configure()
            screenTime.attach(context)
            SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            screenTime.reconcile()
            if AppGroupStore.consumePendingRead(), profiles.first?.onboardingCompleted == true {
                router.showReading = true
            }
            SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        }
        .onOpenURL { url in
            guard url.scheme == PagewormIDs.urlScheme else { return }
            if profiles.first?.onboardingCompleted == true {
                router.showReading = true
            } else {
                AppGroupStore.setPendingRead(true)
            }
        }
        .onChange(of: subscriptions.isPremium) { _, premium in
            SnapshotSync.write(context: context, isPremium: premium)
            screenTime.reconcile()
        }
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "book") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $router.showReading) {
            ReadingSessionView()
        }
        .sheet(isPresented: $router.showPaywall) {
            NavigationStack {
                PaywallView { router.showPaywall = false }
            }
        }
    }
}
