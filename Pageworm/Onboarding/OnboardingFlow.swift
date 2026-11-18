import FamilyControls
import PagewormCore
import SwiftUI

struct OnboardingDraft: Codable, Equatable {
    var step: Int
    var name: String
    var why: String
    var hours: Double
    var apps: [String]
    var goal: Int
    var age: Int
    var schedule: BlockSchedule

    static let fresh = OnboardingDraft(
        step: 0,
        name: "",
        why: Why.miss.sentence,
        hours: 4,
        apps: ["Instagram", "TikTok"],
        goal: 20,
        age: AttentionMath.defaultAge,
        schedule: .allDay
    )

    var answers: QuizAnswers {
        QuizAnswers(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            why: why,
            dailyPhoneHours: hours,
            distractingApps: apps,
            dailyReadingMinutes: goal,
            age: age
        )
    }
}

enum Why: String, CaseIterable, Identifiable {
    case miss, scared, tbr, tired
    var id: String { rawValue }
    var sentence: String {
        switch self {
        case .miss: "I miss reading"
        case .scared: "My screen time scares me"
        case .tbr: "I want to finish my shelf"
        case .tired: "I'm tired of doomscrolling"
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome, name, why, hours, apps, goal, shockYears, shockBooks, playback, pledge
    case screenTime, picker, schedule, notifications, paywall, downsell, trim
}

struct OnboardingFlow: View {
    @EnvironmentObject private var model: PagewormModel
    @State private var draft = OnboardingDraft.fresh
    @State private var selection = FamilyActivitySelection()
    @State private var message: String?
    @State private var working = false

    private var step: OnboardingStep { OnboardingStep(rawValue: draft.step) ?? .welcome }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                HStack {
                    Button {
                        back()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                    }
                    .opacity(step == .downsell ? 0 : 1)
                    .disabled(step == .downsell)
                    Spacer()
                    Text("\(min(step.rawValue + 1, 15)) / 15")
                        .font(Theme.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 12)
            }
            Group {
                switch step {
                case .welcome: welcome
                case .name: nameStep
                case .why: whyStep
                case .hours: hoursStep
                case .apps: appsStep
                case .goal: goalStep
                case .shockYears: shockYears
                case .shockBooks: shockBooks
                case .playback: playback
                case .pledge: pledge
                case .screenTime: screenTime
                case .picker: picker
                case .schedule: schedule
                case .notifications: notifications
                case .paywall:
                    PaywallView(mode: .annual, onPurchased: finishPremium, onDecline: { go(.downsell) })
                case .downsell:
                    PaywallView(mode: .monthly, onPurchased: finishPremium, onDecline: afterDecline)
                case .trim: trim
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(step.rawValue)
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
        }
        .onAppear {
            if let data = UserDefaults.standard.data(forKey: SharedKeys.onboardingDraft),
               let saved = try? JSONDecoder().decode(OnboardingDraft.self, from: data) {
                draft = saved
            }
            selection = SelectionStore.load()
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            InkyView(stage: .bookling, mood: .happy, size: 210)
            VStack(spacing: 10) {
                Text("I'm Inky.")
                    .font(Theme.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("I eat chapters, not notifications. Read a little, and I'll open the apps that have been eating your day.")
                    .font(Theme.rounded(.body))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            Button("Hello, Inky") { go(.name) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    private var nameStep: some View {
        question(title: "What should I call you?", subtitle: "Just a first name. I'll use it when I miss you.") {
            TextField("Your name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .font(Theme.rounded(.title2, weight: .semibold))
                .padding(16)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Button("That's me") { go(.why) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var whyStep: some View {
        question(title: "Why are you here?", subtitle: "I'll remember it in your words.") {
            VStack(spacing: 10) {
                ForEach(Why.allCases) { why in
                    ChoiceChip(title: why.sentence, selected: draft.why == why.sentence) {
                        draft.why = why.sentence
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button("This is why") { go(.hours) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var hoursStep: some View {
        question(title: "How many hours a day does your phone get?", subtitle: "A honest guess is enough. We'll turn it into years in a moment.") {
            VStack(spacing: 8) {
                Text(OnboardingCopy.formatHours(draft.hours))
                    .font(Theme.rounded(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.burgundy)
                    .contentTransition(.numericText())
                Slider(value: $draft.hours, in: 0.5...12, step: 0.5)
                    .tint(Theme.burgundy)
            }
            .padding(18)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Button("That's about right") { go(.apps) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var appsStep: some View {
        let choices = ["Instagram", "TikTok", "YouTube", "X", "Reddit", "Snapchat", "Safari"]
        return question(title: "Which apps steal the reading time?", subtitle: "This is your list. Apple's picker comes next, for the ones I'll actually shut.") {
            FlowChoices(choices: choices, selected: Set(draft.apps)) { app in
                if draft.apps.contains(app) {
                    draft.apps.removeAll { $0 == app }
                } else {
                    draft.apps.append(app)
                }
            }
            Button("They do") { go(.goal) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft.apps.isEmpty)
        }
    }

    private var goalStep: some View {
        question(title: "How long do you want to read each day?", subtitle: "We'll use this, and your real pace, to say when a book ends.") {
            HStack(spacing: 8) {
                ForEach([10, 20, 30, 45, 60], id: \.self) { minutes in
                    ChoiceChip(title: "\(minutes)m", selected: draft.goal == minutes) {
                        draft.goal = minutes
                    }
                }
            }
            Button("That's the plan") { go(.shockYears) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var shockYears: some View {
        let years = AttentionMath.yearsOnPhone(dailyHours: draft.hours, age: draft.age)
        return question(title: "At this rate", subtitle: OnboardingCopy.shockYearsLine(years: years, age: draft.age)) {
            Text(OnboardingCopy.formatYears(years))
                .font(Theme.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.burgundy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            Stepper("Age \(draft.age)", value: $draft.age, in: 13...90)
                .font(Theme.rounded(.body, weight: .semibold))
                .padding(14)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button("Show me the books") { go(.shockBooks) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var shockBooks: some View {
        let books = AttentionMath.booksYouCouldRead(dailyHours: draft.hours, age: draft.age)
        return question(title: "That's a shelf", subtitle: OnboardingCopy.shockBooksLine(books: books, apps: draft.apps)) {
            Text(OnboardingCopy.grouped(books))
                .font(Theme.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(Theme.sage)
            Text("An average book, at a calm 40 pages an hour. Your own pace takes over once you start timing sessions.")
                .font(Theme.rounded(.footnote))
                .foregroundStyle(Theme.inkSoft)
            Button("Say it back to me") { go(.playback) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var playback: some View {
        question(title: "In your words", subtitle: "Read it once. Then we'll sign it.") {
            Text(OnboardingCopy.playback(draft.answers))
                .font(Theme.rounded(.title3, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Button("That's me") { go(.pledge) }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var pledge: some View {
        question(title: "The reading pledge", subtitle: "Hold until the ring closes. It's a small ceremony. I like those.") {
            Text(OnboardingCopy.pledge(name: draft.answers.name))
                .font(Theme.rounded(.title3, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            HoldButton(title: "Hold to sign", hint: "Keep your finger down.") {
                go(.screenTime)
            }
        }
    }

    private var screenTime: some View {
        question(
            title: "I need Apple's permission to shut the door",
            subtitle: "Screen Time lets me cover Instagram and the rest with a screen that has my face on it. Pageworm never sees what you do inside those apps."
        ) {
            InkyView(stage: .bookling, mood: .happy, size: 140)
            if let message {
                Text(message)
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.inkSoft)
            }
            Button(working ? "Asking Apple…" : "Ask Apple") {
                working = true
                Task {
                    message = await model.requestScreenTime()
                    working = false
                    if model.screenTimeApproved { go(.picker) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(working)
            Button("Continue without it for now") { go(.schedule) }
                .buttonStyle(QuietButtonStyle())
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which doors should I hold?")
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Pick the apps. You can choose more than one for now. If you stay on the free plan, we'll keep a single app at the end.")
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.inkSoft)
            FamilyActivityPicker(selection: $selection)
                .frame(maxHeight: .infinity)
            Button("Use these") {
                SelectionStore.save(selection)
                go(.schedule)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private var schedule: some View {
        question(title: "When is the door shut?", subtitle: "During this window the apps stay covered until you finish a reading session. Outside it, they open normally.") {
            ScheduleEditor(schedule: $draft.schedule)
            Button("Set the hours") {
                model.updateSchedule(draft.schedule)
                go(.notifications)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var notifications: some View {
        question(title: "May I nudge you?", subtitle: "I'll speak up before a streak goes quiet, and a minute before an unlock closes. No marketing. Just me.") {
            InkyView(stage: .bookling, mood: .sleepy, size: 140)
            Button("Allow notifications") {
                Task {
                    await model.setNotifications(enabled: true)
                    go(.paywall)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Not now") { go(.paywall) }
                .buttonStyle(QuietButtonStyle())
        }
    }

    private var trim: some View {
        question(
            title: "Free keeps one app",
            subtitle: "Plus would have held all of them. Choose the one door I should keep shut, or clear the picker."
        ) {
            FamilyActivityPicker(selection: $selection)
                .frame(height: 360)
            if let message {
                Text(message).font(Theme.rounded(.footnote)).foregroundStyle(Theme.burgundy)
            }
            Button("Keep this") {
                if let error = model.updateSelection(selection, enforceLimit: true) {
                    message = error
                } else {
                    finishFree()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func question<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)
            Text(title)
                .font(Theme.rounded(.title, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(Theme.rounded(.body))
                .foregroundStyle(Theme.inkSoft)
            content()
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func go(_ next: OnboardingStep) {
        withAnimation(.spring(duration: 0.38)) {
            draft.step = next.rawValue
        }
        persist()
    }

    private func back() {
        let previous = max(0, draft.step - 1)
        withAnimation(.spring(duration: 0.38)) { draft.step = previous }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: SharedKeys.onboardingDraft)
        }
    }

    private func finishPremium() {
        let current = SelectionStore.load()
        _ = model.updateSelection(current.applicationTokens.isEmpty && selection.applicationTokens.isEmpty ? selection : current, enforceLimit: false)
        model.finishOnboarding(draft.answers, signed: true)
        UserDefaults.standard.removeObject(forKey: SharedKeys.onboardingDraft)
    }

    private func afterDecline() {
        selection = SelectionStore.load()
        let gate = FeatureGate(isPremium: false)
        let over = !gate.withinSelectionLimit(
            appCount: selection.applicationTokens.count,
            webCount: selection.webDomainTokens.count,
            categoryCount: selection.categoryTokens.count
        )
        if over {
            go(.trim)
        } else {
            _ = model.updateSelection(selection, enforceLimit: true)
            finishFree()
        }
    }

    private func finishFree() {
        model.finishOnboarding(draft.answers, signed: true)
        UserDefaults.standard.removeObject(forKey: SharedKeys.onboardingDraft)
    }
}

private struct FlowChoices: View {
    var choices: [String]
    var selected: Set<String>
    var toggle: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(choices, id: \.self) { choice in
                ChoiceChip(title: choice, selected: selected.contains(choice)) { toggle(choice) }
            }
        }
    }
}
