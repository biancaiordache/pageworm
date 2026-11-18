import FamilyControls
import PagewormCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: PagewormModel
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var selection = FamilyActivitySelection()
    @State private var schedule = BlockSchedule.allDay
    @State private var status: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Name", text: name)
                    Stepper("Read \(model.profile.dailyReadingMinutes) min a day", value: readingMinutes, in: 5...180, step: 5)
                    Stepper("A chapter is about \(model.profile.pagesPerChapter) pages", value: chapterLength, in: 5...60, step: 1)
                }
                Section("The door") {
                    Toggle("Blocking", isOn: blocking)
                    if model.profile.strictMode {
                        Text("Strict mode is on. Hold below to turn it off.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HoldButton(title: "Hold to leave strict mode", hint: "This opens the settings, not the apps.") {
                            _ = model.setStrict(false)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } else {
                        Toggle("Strict mode", isOn: strict)
                    }
                    Picker("Unlock length", selection: unlock) {
                        ForEach(UnlockPolicy.allowedMinutes, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    ScheduleEditor(schedule: $schedule)
                        .onChange(of: schedule) { _, newValue in
                            var copy = newValue
                            copy.enabled = model.profile.blockingEnabled
                            model.updateSchedule(copy)
                        }
                }
                Section("Apps") {
                    FamilyActivityPicker(selection: $selection)
                        .frame(height: 280)
                    Button("Save the doors") {
                        status = model.updateSelection(selection, enforceLimit: true)
                    }
                    if !model.screenTimeApproved {
                        Button("Ask Apple for Screen Time") {
                            Task { status = await model.requestScreenTime() }
                        }
                    }
                }
                Section("Inky") {
                    Toggle("Nudges", isOn: nudges)
                    HStack {
                        Text("Plan")
                        Spacer()
                        Text(model.profile.isPremium ? "Plus" : "Free")
                            .foregroundStyle(.secondary)
                    }
                    if RevenueCatConfig.isPlaceholder {
                        Text("RevenueCat key is still the placeholder in RevenueCatConfig.swift.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button(model.profile.isPremium ? "Manage Plus" : "See Plus") { model.showPaywall = true }
                    Button("Restore purchase") {
                        Task {
                            let restored = await purchases.restore()
                            status = restored ? "Plus is on." : purchases.lastError
                        }
                    }
                }
                if let status {
                    Section {
                        Text(status).font(.footnote)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                selection = SelectionStore.load()
                schedule = model.profile.schedule
            }
            .sheet(isPresented: Binding(get: { model.showPaywall }, set: { model.showPaywall = $0 })) {
                SettingsPaywall()
                    .environmentObject(model)
                    .environmentObject(purchases)
            }
        }
    }

    private var name: Binding<String> {
        Binding(get: { model.profile.name }, set: { model.profile.name = $0; trySave() })
    }

    private var readingMinutes: Binding<Int> {
        Binding(get: { model.profile.dailyReadingMinutes }, set: { model.profile.dailyReadingMinutes = $0; trySave() })
    }

    private var chapterLength: Binding<Int> {
        Binding(get: { model.profile.pagesPerChapter }, set: { model.profile.pagesPerChapter = $0; trySave() })
    }

    private var blocking: Binding<Bool> {
        Binding(
            get: { model.profile.blockingEnabled },
            set: { newValue in
                status = model.setBlockingEnabled(newValue)
                schedule.enabled = model.profile.blockingEnabled
            }
        )
    }

    private var strict: Binding<Bool> {
        Binding(
            get: { model.profile.strictMode },
            set: { status = model.setStrict($0) }
        )
    }

    private var unlock: Binding<Int> {
        Binding(
            get: { model.profile.unlockMinutes },
            set: { status = model.setUnlockMinutes($0) }
        )
    }

    private var nudges: Binding<Bool> {
        Binding(
            get: { model.profile.notificationsEnabled },
            set: { enabled in
                Task { await model.setNotifications(enabled: enabled) }
            }
        )
    }

    private func trySave() {
        model.updateSchedule(model.profile.schedule)
    }
}

private struct SettingsPaywall: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var model: PagewormModel
    @State private var downsell = false

    var body: some View {
        Group {
            if downsell {
                PaywallView(mode: .monthly, onPurchased: close, onDecline: close)
            } else {
                PaywallView(mode: .annual, onPurchased: close, onDecline: { downsell = true })
            }
        }
        .environmentObject(purchases)
        .background(CozyBackground())
    }

    private func close() {
        model.showPaywall = false
    }
}
