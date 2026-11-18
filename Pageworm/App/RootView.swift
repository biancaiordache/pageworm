import PagewormCore
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @State private var model: PagewormModel?

    var body: some View {
        ZStack {
            CozyBackground()
            if let model, let profile = profiles.first {
                Group {
                    if profile.onboardingComplete {
                        MainTabView()
                    } else {
                        OnboardingFlow()
                    }
                }
                .environmentObject(model)
                .environmentObject(model.purchases)
            }
        }
        .onAppear {
            if model == nil {
                let created = PagewormModel(context: context)
                created.start()
                model = created
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model?.sceneBecameActive()
            if SharedStore.consumePendingRead(in: AppGroupDefaults.suite()) {
                model?.openReadingFromOutside()
            }
        }
        .onOpenURL { model?.handle(url: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .pagewormShieldWantsRead)) { _ in
            model?.openReadingFromOutside()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var model: PagewormModel

    var body: some View {
        TabView(selection: Binding(get: { model.tab }, set: { model.tab = $0 })) {
            HomeView()
                .tabItem { Label("Home", systemImage: "book.closed") }
                .tag(AppTab.home)
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppTab.library)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(AppTab.insights)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.burgundy)
    }
}
