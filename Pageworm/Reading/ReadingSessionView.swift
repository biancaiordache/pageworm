import Combine
import PagewormCore
import SwiftUI

struct ReadingSessionView: View {
    @EnvironmentObject private var model: PagewormModel
    @Environment(\.dismiss) private var dismiss
    var book: Book

    @State private var startPage = ""
    @State private var endPage = ""
    @State private var stopping = false
    @State private var error: String?
    @State private var now = Date()

    private var running: ActiveSessionState? {
        guard let session = model.activeSession, session.bookID == book.id.uuidString else { return nil }
        return session
    }

    var body: some View {
        ZStack {
            CozyBackground()
            VStack(spacing: 22) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(Theme.rounded(.body, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                }
                InkyView(stage: .pageNibbler, mood: running == nil ? .happy : .sleepy, size: 160)
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(Theme.rounded(.title2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    Text(book.author)
                        .font(Theme.rounded(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                }
                if let running {
                    Text(timerInterval: running.startedAt...now.addingTimeInterval(60 * 60 * 12), countsDown: false)
                        .font(Theme.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(Theme.burgundy)
                        .monospacedDigit()
                    Text("Started at page \(running.startPage). A minute or more opens the apps.")
                        .font(Theme.rounded(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button("Stop and enter the page") { stopping = true }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    pageField(title: "Starting page", text: $startPage)
                    Button("Begin") { begin() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                if let error {
                    Text(error)
                        .font(Theme.rounded(.footnote))
                        .foregroundStyle(Theme.burgundy)
                }
                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            if startPage.isEmpty { startPage = "\(book.currentPage)" }
            now = Date()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .sheet(isPresented: $stopping) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Where did you stop?")
                        .font(Theme.rounded(.title2, weight: .bold))
                    pageField(title: "Ending page", text: $endPage)
                    Button("Save the session") { commit() }
                        .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding(24)
                .background(CozyBackground())
                .navigationTitle("Pages")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .onAppear {
                if endPage.isEmpty { endPage = "\(running?.startPage ?? book.currentPage)" }
            }
        }
    }

    private func pageField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.rounded(.caption, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .font(Theme.rounded(.title, weight: .bold))
                .padding(14)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func begin() {
        let page = Int(startPage) ?? book.currentPage
        guard page >= 0 else {
            error = "Pages start at zero."
            return
        }
        book.currentPage = page
        model.beginReading(book)
        error = nil
    }

    private func commit() {
        guard let page = Int(endPage) else {
            error = "Enter the page you stopped on."
            return
        }
        if let message = model.stopReading(book: book, endPage: page) {
            error = message
        } else {
            stopping = false
            dismiss()
        }
    }
}
