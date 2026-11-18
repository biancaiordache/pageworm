import FamilyControls
import SwiftUI
import PagewormCore
import PagewormDesign

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @Environment(ScreenTimeManager.self) private var screenTime
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var step = 0
    @State private var name = ""
    @State private var why = ""
    @State private var customWhy = ""
    @State private var hours: Double = 4
    @State private var apps: Set<String> = []
    @State private var goal = 30
    @State private var shockPhase = 0
    @State private var pledged = false
    @State private var scheduleStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var scheduleEnd = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @State private var allDay = false
    @State private var scheduleMessage: String?

    private let steps = 14
    private let whyChoices = [
        "your evenings back",
        "to finish the books you already own",
        "to sleep before midnight",
        "to be someone who reads"
    ]
    private let appChoices = ["Instagram", "TikTok", "YouTube", "X", "Reddit", "Safari", "Netflix"]
    private let goals = [10, 20, 30, 45, 60]

    var body: some View {
        PaperScreen {
            VStack(spacing: 16) {
                StepHeader(index: step, count: steps)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                Group {
                    switch step {
                    case 0: welcome
                    case 1: nameStep
                    case 2: whyStep
                    case 3: hoursStep
                    case 4: appsStep
                    case 5: goalStep
                    case 6: shockStep
                    case 7: playbackStep
                    case 8: pledgeStep
                    case 9: screenTimeStep
                    case 10: pickerStep
                    case 11: scheduleStep
                    case 12: notificationStep
                    default: paywallStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: restore)
        .animation(.spring(duration: 0.35), value: step)
    }

    private var welcome: some View {
        stepStack {
            InkyView(mood: .happy, size: 190)
            InkyBubble(text: "Hi, I'm Inky. I live in books, and I get lonely when your phone eats the day.")
            Text("Read a little. I'll step off the apps that eat the rest.")
                .font(PagewormFont.rounded(.title3, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pwInk)
            advance("Let's begin")
        }
    }

    private var nameStep: some View {
        stepStack {
            InkyView(mood: .happy, size: 120, animated: false)
            InkyBubble(text: "What should I call you?")
            TextField("Your name", text: $name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            advance("That's me")
        }
    }

    private var whyStep: some View {
        stepStack {
            InkyBubble(text: "What do you want your reading time back for?")
            chipWrap(whyChoices, selected: why) { why = $0; customWhy = "" }
            TextField("Or say it your way", text: $customWhy)
                .padding(14)
                .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            advance("That's why", disabled: resolvedWhy.isEmpty)
        }
    }

    private var hoursStep: some View {
        stepStack {
            InkyBubble(text: "How many hours does your phone usually get?")
            Text(DurationText.hours(hours))
                .font(PagewormFont.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(Color.pwInk)
            Slider(value: $hours, in: 0.5...12, step: 0.5)
                .tint(Color.pwMoss)
            advance("That's about right")
        }
    }

    private var appsStep: some View {
        stepStack {
            InkyBubble(text: "Which apps steal the chapters?")
            chipWrap(appChoices, selectedMany: apps) { app in
                if apps.contains(app) { apps.remove(app) } else { apps.insert(app) }
            }
            advance("Those ones")
        }
    }

    private var goalStep: some View {
        stepStack {
            InkyBubble(text: "How many minutes of reading would feel like a win?")
            chipWrap(goals.map(String.init), selected: "\(goal)") { goal = Int($0) ?? 30 }
            advance("That's the goal")
        }
    }

    private var shockStep: some View {
        let shock = ShockMath.calculate(dailyPhoneHours: hours)
        return stepStack {
            InkyView(mood: shockPhase == 0 ? .sleepy : .missingYou, size: 140)
            Text(shockPhase == 0 ? InkyCopy.shockYears(shock) : InkyCopy.shockBooks(shock))
                .font(PagewormFont.rounded(.title2, weight: .bold))
                .foregroundStyle(Color.pwInk)
                .multilineTextAlignment(.center)
            if shockPhase == 0 {
                Button("That's not all") { withAnimation { shockPhase = 1 } }
                    .buttonStyle(InkButtonStyle())
            } else {
                advance("I want those books")
            }
        }
    }

    private var playbackStep: some View {
        stepStack {
            InkyView(mood: .happy, size: 120, animated: false)
            InkyBubble(text: "Let me say it back.")
            Text(InkyCopy.playback(name: name, why: resolvedWhy, dailyHours: hours, apps: selectedApps, goalMinutes: goal))
                .font(PagewormFont.rounded(.title3, weight: .semibold))
                .foregroundStyle(Color.pwInk)
                .multilineTextAlignment(.center)
            advance("That's me")
        }
    }

    private var pledgeStep: some View {
        stepStack {
            InkyBubble(text: "Hold to promise me.")
            if pledged {
                advance("I'm in")
            } else {
                HoldToConfirmButton(title: InkyCopy.pledge(name: name), subtitle: "Keep holding. I can feel it.") {
                    pledged = true
                    save()
                }
            }
        }
    }

    private var screenTimeStep: some View {
        stepStack {
            InkyView(mood: .happy, size: 130)
            InkyBubble(text: "I need Apple's Screen Time permission to stand guard. I only block the apps you pick.")
            if let message = screenTime.lastMessage {
                Text(message)
                    .font(PagewormFont.rounded(.footnote))
                    .foregroundStyle(Color.pwInkSoft)
                    .multilineTextAlignment(.center)
            }
            Button("Let Inky stand guard") {
                Task {
                    await screenTime.requestAuthorization()
                    if screenTime.isAuthorized { go(10) }
                }
            }
            .buttonStyle(InkButtonStyle())
            Button("I'll do this later") { go(10) }
                .font(PagewormFont.rounded(.body, weight: .semibold))
                .foregroundStyle(Color.pwInkSoft)
        }
    }

    private var pickerStep: some View {
        VStack(spacing: 12) {
            InkyBubble(text: screenTime.isAuthorized
                ? "Tap the apps I should curl up in front of. The free plan keeps one."
                : "Screen Time isn't on yet, so I can't see your apps. You can pick them in Settings later.")
            if screenTime.isAuthorized {
                FamilyActivityPicker(selection: selectionBinding)
                    .frame(maxHeight: .infinity)
            }
            if let message = screenTime.lastMessage {
                Text(message).font(PagewormFont.rounded(.footnote)).foregroundStyle(Color.pwSpine)
            }
            Button("Use these") {
                if let message = screenTime.updateSelection(screenTime.selection, isPremium: subscriptions.isPremium) {
                    screenTime.lastMessage = message
                } else {
                    go(11)
                }
            }
            .buttonStyle(InkButtonStyle())
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 12)
    }

    private var selectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { screenTime.selection },
            set: { screenTime.selection = $0 }
        )
    }

    private var scheduleStep: some View {
        stepStack {
            InkyBubble(text: "When should I be on duty?")
            Toggle("All day", isOn: $allDay)
                .tint(Color.pwMoss)
            if !allDay {
                DatePicker("Starts", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
            }
            if let scheduleMessage {
                Text(scheduleMessage)
                    .font(PagewormFont.rounded(.footnote))
                    .foregroundStyle(Color.pwSpine)
            }
            Button("That's the watch") {
                let built = makeSchedule()
                if let message = screenTime.updateSchedule(built) {
                    scheduleMessage = message
                } else {
                    scheduleMessage = nil
                    go(12)
                }
            }
            .buttonStyle(InkButtonStyle())
        }
    }

    private var notificationStep: some View {
        stepStack {
            InkyView(mood: .sleepy, size: 130)
            InkyBubble(text: "Can I tap the glass when your streak is getting sleepy?")
            Button("Yes, nudge me") {
                Task {
                    let allowed = await InkyNotifications.requestAuthorization()
                    let profile = Store.profile(context)
                    profile.notificationsAllowed = allowed
                    if allowed {
                        InkyNotifications.scheduleDaily(name: name, atRisk: false)
                    }
                    go(13)
                }
            }
            .buttonStyle(InkButtonStyle())
            Button("Not now") { go(13) }
                .font(PagewormFont.rounded(.body, weight: .semibold))
                .foregroundStyle(Color.pwInkSoft)
        }
    }

    private var paywallStep: some View {
        PaywallView {
            finishOnboarding()
        }
    }

    private func stepStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                content()
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func advance(_ title: String, disabled: Bool = false) -> some View {
        Button(title) { go(step + 1) }
            .buttonStyle(InkButtonStyle())
            .disabled(disabled)
    }

    private func chipWrap(_ titles: [String], selected: String, tap: @escaping (String) -> Void) -> some View {
        chipWrap(titles, isSelected: { $0 == selected }, tap: tap)
    }

    private func chipWrap(_ titles: [String], selectedMany: Set<String>, tap: @escaping (String) -> Void) -> some View {
        chipWrap(titles, isSelected: { selectedMany.contains($0) }, tap: tap)
    }

    private func chipWrap(_ titles: [String], isSelected: @escaping (String) -> Bool, tap: @escaping (String) -> Void) -> some View {
        FlowChips(titles: titles, isSelected: isSelected, tap: tap)
    }

    private var resolvedWhy: String {
        let custom = customWhy.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? why : custom
    }

    private var selectedApps: [String] {
        appChoices.filter { apps.contains($0) }
    }

    private func makeSchedule() -> BlockSchedule {
        if allDay { return .allDay }
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: scheduleStart)
        let end = calendar.dateComponents([.hour, .minute], from: scheduleEnd)
        return BlockSchedule(
            enabled: true,
            startHour: start.hour ?? 9,
            startMinute: start.minute ?? 0,
            endHour: end.hour ?? 21,
            endMinute: end.minute ?? 0
        )
    }

    private func go(_ next: Int) {
        save()
        step = min(next, steps - 1)
    }

    private func restore() {
        let profile = Store.profile(context)
        name = profile.name
        why = profile.whyHere
        hours = profile.dailyPhoneHours
        apps = Set(profile.distractingApps)
        goal = profile.dailyReadingGoalMinutes
        pledged = profile.pledgeSignedAt != nil
        step = profile.onboardingCompleted ? steps - 1 : profile.onboardingStep
        let block = Store.block(context)
        allDay = block.startHour == 0 && block.endHour == 23
        scheduleStart = Calendar.current.date(from: DateComponents(hour: block.startHour, minute: block.startMinute)) ?? scheduleStart
        scheduleEnd = Calendar.current.date(from: DateComponents(hour: block.endHour, minute: block.endMinute)) ?? scheduleEnd
    }

    private func save() {
        let profile = Store.profile(context)
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.whyHere = resolvedWhy
        profile.dailyPhoneHours = hours
        profile.distractingApps = selectedApps
        profile.dailyReadingGoalMinutes = goal
        profile.onboardingStep = step
        if pledged, profile.pledgeSignedAt == nil {
            profile.pledgeSignedAt = Date()
        }
        try? context.save()
    }

    private func finishOnboarding() {
        let profile = Store.profile(context)
        save()
        profile.onboardingCompleted = true
        profile.onboardingStep = steps - 1
        try? context.save()
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        if profile.notificationsAllowed {
            let health = StreakEngine.health(state: Store.streak(context).state, today: Date(), allowFreeze: subscriptions.isPremium, calendar: .current)
            let atRisk: Bool
            if case .atRisk(_) = health { atRisk = true } else { atRisk = false }
            InkyNotifications.scheduleDaily(name: profile.name, atRisk: atRisk)
        }
    }
}

private struct FlowChips: View {
    var titles: [String]
    var isSelected: (String) -> Bool
    var tap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(titles, id: \.self) { title in
                ChoiceChip(title: title, selected: isSelected(title)) { tap(title) }
            }
        }
    }
}
