import SwiftUI
import UniformTypeIdentifiers
import PagewormCore
import PagewormDesign

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(AppRouter.self) private var router
    @Query(sort: \Book.title) private var books: [Book]
    @State private var shelf: ReadingShelf = .currentlyReading
    @State private var importing = false
    @State private var summary: ImportSummary?
    @State private var showAdd = false

    private var visible: [Book] {
        books.filter { $0.shelf == shelf }
    }

    var body: some View {
        NavigationStack {
            PaperScreen {
                VStack(spacing: 12) {
                    Picker("Shelf", selection: $shelf) {
                        Text("Reading").tag(ReadingShelf.currentlyReading)
                        Text("To read").tag(ReadingShelf.toRead)
                        Text("Finished").tag(ReadingShelf.read)
                        Text("Set aside").tag(ReadingShelf.didNotFinish)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if visible.isEmpty {
                        Spacer()
                        InkyView(mood: .sleepy, size: 120, animated: false)
                        Text(emptyCopy)
                            .font(PagewormFont.rounded(.body))
                            .foregroundStyle(Color.pwInkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    } else {
                        List {
                            ForEach(visible) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    HStack(spacing: 12) {
                                        BookCover(url: book.coverURL, title: book.title)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(book.title)
                                                .font(PagewormFont.rounded(.headline, weight: .semibold))
                                            Text(book.authors)
                                                .font(PagewormFont.rounded(.subheadline))
                                                .foregroundStyle(Color.pwInkSoft)
                                            if let total = book.pageCount {
                                                Text("\(book.currentPage)/\(total)")
                                                    .font(PagewormFont.rounded(.caption, weight: .semibold))
                                                    .foregroundStyle(Color.pwMoss)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Import") {
                        Button("Goodreads CSV") { importing = true }
                        Button("StoryGraph CSV") {
                            if subscriptions.isPremium {
                                importing = true
                            } else {
                                router.showPaywall = true
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { showAdd = true }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                if case .success(let url) = result {
                    summary = LibraryImporter.importFile(url: url, context: context, allowStoryGraph: subscriptions.isPremium)
                    if summary?.needsPremium == true {
                        router.showPaywall = true
                    } else {
                        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddBookView()
            }
            .alert("Shelf updated", isPresented: Binding(get: { summary != nil && summary?.needsPremium != true }, set: { if !$0 { summary = nil } })) {
                Button("OK", role: .cancel) { summary = nil }
            } message: {
                Text(summaryText)
            }
        }
    }

    private var emptyCopy: String {
        switch shelf {
        case .currentlyReading: return "Nothing is open. Import a library or add the book on your nightstand."
        case .toRead: return "Your to-read shelf is empty."
        case .read: return "Finished books will land here. Ones you finish in Pageworm help Inky grow."
        case .didNotFinish: return "Set-aside books from an import show up here."
        case .other: return "Nothing here."
        }
    }

    private var summaryText: String {
        guard let summary else { return "" }
        return "Added \(summary.added), updated \(summary.updated). \(summary.reading) currently reading, \(summary.toRead) to-read, \(summary.finished) finished. Skipped \(summary.skipped)."
    }
}

struct BookDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptions
    @Bindable var book: Book
    @State private var lookingUp = false
    @State private var lookupMessage: String?

    var body: some View {
        PaperScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        BookCover(url: book.coverURL, title: book.title)
                            .frame(width: 84, height: 120)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title).font(PagewormFont.rounded(.title3, weight: .bold))
                            Text(book.authors).foregroundStyle(Color.pwInkSoft)
                            Text(book.shelf.title).font(PagewormFont.rounded(.caption, weight: .semibold)).foregroundStyle(Color.pwMoss)
                        }
                    }
                    Stepper("Current page \(book.currentPage)", value: $book.currentPage, in: 0...max(book.pageCount ?? 20000, book.currentPage))
                    Stepper("Pages in a chapter \(book.chapterLength)", value: $book.chapterLength, in: 5...80)
                    HStack {
                        Text("Page count")
                        Spacer()
                        TextField("Pages", text: Binding(
                        get: { book.pageCount.map(String.init) ?? "" },
                        set: { book.pageCount = Int($0.trimmingCharacters(in: .whitespaces)) }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    }
                    forecast
                    Button(book.isCurrent ? "This is the current book" : "Make this the current book") {
                        for other in Store.books(context) { other.isCurrent = false }
                        book.isCurrent = true
                        if book.shelf == .toRead { book.shelf = .currentlyReading }
                        try? context.save()
                        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
                    }
                    .buttonStyle(InkButtonStyle(prominent: !book.isCurrent))
                    Button(lookingUp ? "Looking…" : "Fetch cover and pages") { Task { await lookup() } }
                        .buttonStyle(InkButtonStyle(prominent: false))
                        .disabled(lookingUp)
                    if let lookupMessage {
                        Text(lookupMessage).font(PagewormFont.rounded(.footnote)).foregroundStyle(Color.pwInkSoft)
                    }
                    if book.shelf != .read {
                        Button("Mark finished") {
                            book.shelf = .read
                            book.finishedAt = Date()
                            book.countsTowardInky = true
                            book.isCurrent = false
                            if let pages = book.pageCount { book.currentPage = pages }
                            try? context.save()
                            SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
                        }
                        .buttonStyle(InkButtonStyle(prominent: false))
                    }
                    Button("Delete book", role: .destructive) {
                        context.delete(book)
                        try? context.save()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? context.save()
            SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        }
    }

    @ViewBuilder
    private var forecast: some View {
        let built = PaceBuilder.pace(context: context)
        if let remaining = book.remainingPages,
           let forecast = ForecastMath.forecast(remainingPages: remaining, pace: built.pace, today: Date(), calendar: .current) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Finish forecast")
                    .font(PagewormFont.rounded(.headline, weight: .bold))
                Text("\(formatted(forecast.hoursRemaining)) · \(forecast.sessionsRemaining) sessions · \(forecast.finishDate.formatted(date: .abbreviated, time: .omitted))")
                if subscriptions.isPremium {
                    let app = Store.profile(context).distractingApps.first ?? "scroll"
                    Text("Swap one daily \(app) hour and it's \(forecast.swappedFinishDate.formatted(date: .abbreviated, time: .omitted)).")
                        .foregroundStyle(Color.pwMoss)
                }
            }
            .font(PagewormFont.rounded(.subheadline))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pwCream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func lookup() async {
        lookingUp = true
        defer { lookingUp = false }
        guard let meta = await MetadataClient().lookup(isbn: book.isbn, title: book.title, author: book.authors) else {
            lookupMessage = "Neither Open Library nor Google Books had this one. You can type the page count."
            return
        }
        if book.pageCount == nil { book.pageCount = meta.pageCount }
        if book.coverURL == nil { book.coverURL = meta.coverURL?.absoluteString }
        if book.isbn == nil { book.isbn = meta.isbn13 }
        lookupMessage = meta.pageCount == nil ? "Found a cover, but no page count." : "Updated from the catalog."
        try? context.save()
    }

    private func formatted(_ hours: Double) -> String {
        hours < 1 ? "\(max(1, Int((hours * 60).rounded()))) min" : DurationText.hours(hours)
    }
}

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var title = ""
    @State private var authors = ""
    @State private var pages = ""
    @State private var isbn = ""
    @State private var shelf: ReadingShelf = .toRead
    @State private var lookingUp = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            PaperScreen {
                Form {
                    TextField("Title", text: $title)
                    TextField("Author", text: $authors)
                    TextField("Pages", text: $pages).keyboardType(.numberPad)
                    TextField("ISBN", text: $isbn)
                    Picker("Shelf", selection: $shelf) {
                        Text("To read").tag(ReadingShelf.toRead)
                        Text("Reading").tag(ReadingShelf.currentlyReading)
                    }
                    Button(lookingUp ? "Looking…" : "Look up pages and cover") { Task { await lookup() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || lookingUp)
                    if let message {
                        Text(message).font(PagewormFont.rounded(.footnote))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add a book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            authors: authors.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: ISBNNormalizer.normalize(isbn),
            pageCount: Int(pages),
            shelf: shelf,
            source: .manual
        )
        if shelf == .currentlyReading {
            for other in Store.books(context) { other.isCurrent = false }
            book.isCurrent = true
        }
        context.insert(book)
        try? context.save()
        SnapshotSync.write(context: context, isPremium: subscriptions.isPremium)
        dismiss()
    }

    private func lookup() async {
        lookingUp = true
        defer { lookingUp = false }
        guard let meta = await MetadataClient().lookup(isbn: isbn, title: title, author: authors) else {
            message = "No catalog match yet. You can still save it."
            return
        }
        if title.isEmpty, let found = meta.title { title = found }
        if authors.isEmpty, let found = meta.authors { authors = found }
        if pages.isEmpty, let count = meta.pageCount { pages = String(count) }
        if isbn.isEmpty, let found = meta.isbn13 { isbn = found }
        message = "Filled in what the catalog knew."
    }
}
