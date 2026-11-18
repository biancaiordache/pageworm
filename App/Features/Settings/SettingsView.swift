import FamilyControls
import SwiftUI
import PagewormCore
import PagewormDesign

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [UserProfile]
    @State private var hours: Double = 4
    @State private var goal = 30
    @State private var name = ""
    @State private var scheduleStart = Date()
    @State private var scheduleEnd = Date()
    @State private var message: String?

    var body: some View {
        NavigationStack {
            PaperScreen {
                Form {
                    Section("You") {
                        TextField("Name", text: $name)
                        HStack {
                            Text("Phone hours")
                            Slider(value: $hours, in: 0.5...12, step: 0.5)
                            Text(DurationText.hours(hours)).frame(width: 72, alignment: .trailing)
                        }
                        Stepper("Reading goal \(goal) min", value: $goal, in: 5...180, step: 5)
                        Button("Save") { saveProfile() }
                    }
                    Section("Blocking") {
                        if screenTime.isAuthorized {
                            Text(screenTime.status == .approved ? "Screen Time is on." : "Screen Time is off.")
                        } else {
                            Button("Ask for Screen Time") {
                                Task { await screenTime.requestAuthorization() }
                            }
                        }
                        DatePicker("Block starts", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                        DatePicker("Block ends", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                        Button("Save schedule") { saveSchedule() }
                        if screenTime.strictMode {
                            Text("Strict mode is on. Hold below to turn it off before changing the app list.")
                                .font(PagewormFont.rounded(.footnote))
                            HoldToConfirmButton(title: "Turn strict mode off", subtitle: "Hold so it isn't a reflex.") {
                                message = screenTime.setStrictMode(false, isPremium: subscriptions.isPremium)
                                confirmStrictOff = true
                            }
                        } else {
                            Toggle("Strict mode", isOn: strictBinding)
                        }
                        Picker("Unlock length", selection: unlockBinding) {
                            ForEach(UnlockPolicy.choices, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        if screenTime.strictMode {
                            Button("Hold for an emergency unlock") {}
                                .disabled(true)
                            HoldToConfirmButton(
                                title: "Emergency unlock",
                                subtitle: "\(screenTime.emergencyRemaining(isPremium: subscriptions.isPremium)) left this week"
                            ) {
                                message = screenTime.redeemEmergency(isPremium: subscriptions.isPremium)
                            }
                        }
                        if screenTime.isAuthorized && !screenTime.strictMode {
                            FamilyActivityPicker(selection: selectionBinding)
                                .frame(height: 360)
                            Button("Save blocked apps") {
                                message = screenTime.updateSelection(screenTime.selection, isPremium: subscriptions.isPremium)
                            }
                        }
                    }
                    Section("Pageworm Plus") {
                        Text(subscriptions.isPremium ? "Plus is active." : "Free: one blocked app, Goodreads import, finish forecast.")
                        Button(subscriptions.isPremium ? "Manage Plus" : "See Plus") { router.showPaywall = true }
                        Button("Restore purchases") { Task { _ = await subscriptions.restore() } }
                    }
                    Section("Inky") {
                        Button("Replay onboarding") { replay() }
                        Button("Delete all books", role: .destructive) { deleteBooks() }
                    }
                    if let message {
                        Section { Text(message).foregroundStyle(Color.pwSpine) }
                    }
                    if let error = subscriptions.lastError {
                        Section { Text(error) }
                    }
                    Section {
                        Text("Pageworm \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .foregroundStyle(Color.pwInkSoft)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .onAppear(perform: load)
        }
    }

    private var strictBinding: Binding<Bool> {
        Binding(
            get: { screenTime.strictMode },
            set: { newValue in
                message = screenTime.setStrictMode(newValue, isPremium: subscriptions.isPremium)
            }
        )
    }

    private var unlockBinding: Binding<Int> {
        Binding(
            get: { screenTime.unlockMinutes },
            set: { message = screenTime.setUnlockMinutes($0, isPremium: subscriptions.isPremium) }
        )
    }

    private var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(get: { screenTime.selection }, set: { screenTime.selection = $0 })
    }

    private func load() {
        let profile = profiles.first ?? Store.profile(context)
        name = profile.name
        hours = profile.dailyPhoneHours
        goal = profile.dailyReadingGoalMinutes
        let calendar = Calendar.current
        scheduleStart = calendar.date(from: DateComponents(hour: screenTime.schedule.startHour, minute: screenTime.schedule.startMinute)) ?? Date()
        scheduleEnd = calendar.date(from: DateComponents(hour: screenTime.schedule.endHour, minute: screenTime.schedule.endMinute)) ?? Date()
    }

    private func saveProfile() {
        let profile = Store.profile(context)
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.dailyPhoneHours = hours
        profile.dailyReadingGoalMinutes = goal
        try? context.save()
        if profile.notificationsAllowed {
            InkyNotifications.scheduleDaily(name: profile.name, atRisk: false)
        }
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        message = "Saved."
    }

    private func saveSchedule() {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: scheduleStart)
        let end = calendar.dateComponents([.hour, .minute], from: scheduleEnd)
        let schedule = BlockSchedule(
            enabled: true,
            startHour: start.hour ?? 9,
            startMinute: start.minute ?? 0,
            endHour: end.hour ?? 21,
            endMinute: end.minute ?? 0
        )
        message = screenTime.updateSchedule(schedule) ?? "Schedule saved."
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
    }

    private func replay() {
        let profile = Store.profile(context)
        profile.onboardingCompleted = false
        profile.onboardingStep = 0
        try? context.save()
    }

    private func deleteBooks() {
        for book in Store.books(context) {
            context.delete(book)
        }
        try? context.save()
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
    }
}
