import PagewormCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var model: PagewormModel
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @State private var importing = false
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if books.isEmpty {
                        empty
                    }
                    shelf(.currentlyReading)
                    shelf(.toRead)
                    shelf(.read)
                }
                .padding(20)
            }
            .background(CozyBackground())
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Import") { importing = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { adding = true }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                if case let .success(url) = result {
                    model.importFile(at: url)
                }
            }
            .sheet(isPresented: $adding) {
                AddBookSheet()
            }
        }
    }

    private var empty: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No books yet.")
                    .font(Theme.rounded(.headline, weight: .bold))
                Text("Export your Goodreads library to CSV and import it here. StoryGraph works too, on Plus.")
                    .font(Theme.rounded(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    @ViewBuilder
    private func shelf(_ shelf: ReadingShelf) -> some View {
        let items = books.filter { $0.shelf == shelf }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(shelf.title)
                    .font(Theme.rounded(.title3, weight: .bold))
                    .foregroundStyle(Theme.ink)
                ForEach(items) { book in
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        HStack(spacing: 12) {
                            BookCover(title: book.title, url: book.coverURL)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(Theme.rounded(.headline, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(book.author)
                                    .font(Theme.rounded(.subheadline))
                                    .foregroundStyle(Theme.inkSoft)
                                if let pages = book.pageCount {
                                    Text("\(book.currentPage)/\(pages) pages")
                                        .font(Theme.rounded(.caption))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct BookDetailView: View {
    @EnvironmentObject private var model: PagewormModel
    @Query private var sessions: [ReadingSessionRecord]
    @Query private var books: [Book]
    var book: Book
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    BookCover(title: book.title, url: book.coverURL)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(Theme.rounded(.title2, weight: .bold))
                        Text(book.author)
                            .foregroundStyle(Theme.inkSoft)
                        Text(book.shelf.title)
                            .font(Theme.rounded(.caption, weight: .bold))
                            .foregroundStyle(Theme.burgundy)
                    }
                }
                if let forecast = model.progress(books: books, sessions: sessions).forecast(for: book) {
                    PaperCard {
                        ForecastBlock(
                            forecast: forecast,
                            appName: OnboardingCopy.scrollSwapName(apps: model.profile.distractingApps)
                        )
                    }
                }
                Button("Start reading") { model.beginReading(book) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Make this the current book") { model.makeCurrent(book) }
                    .buttonStyle(QuietButtonStyle())
                Button("Edit") { editing = true }
                    .buttonStyle(QuietButtonStyle())
                Button("Remove from the shelf", role: .destructive) { model.delete(book) }
                    .font(Theme.rounded(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.burgundy)
            }
            .padding(20)
        }
        .background(CozyBackground())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            EditBookSheet(book: book)
        }
    }
}

struct AddBookSheet: View {
    @EnvironmentObject private var model: PagewormModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var pages = ""
    @State private var shelf: ReadingShelf = .toRead

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
                TextField("Pages", text: $pages)
                    .keyboardType(.numberPad)
                Picker("Shelf", selection: $shelf) {
                    Text("To read").tag(ReadingShelf.toRead)
                    Text("Currently reading").tag(ReadingShelf.currentlyReading)
                }
            }
            .navigationTitle("Add a book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.addBook(title: title, author: author, pages: Int(pages), shelf: shelf)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct EditBookSheet: View {
    @EnvironmentObject private var model: PagewormModel
    @Environment(\.dismiss) private var dismiss
    var book: Book
    @State private var title = ""
    @State private var author = ""
    @State private var pages = ""
    @State private var current = ""
    @State private var shelf: ReadingShelf = .toRead

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Author", text: $author)
                TextField("Pages", text: $pages).keyboardType(.numberPad)
                TextField("Current page", text: $current).keyboardType(.numberPad)
                Picker("Shelf", selection: $shelf) {
                    ForEach(ReadingShelf.allCases, id: \.rawValue) { item in
                        Text(item.title).tag(item)
                    }
                }
            }
            .navigationTitle("Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.update(
                            book: book,
                            title: title,
                            author: author,
                            pages: Int(pages),
                            currentPage: Int(current) ?? book.currentPage,
                            shelf: shelf
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = book.title
                author = book.author
                pages = book.pageCount.map(String.init) ?? ""
                current = "\(book.currentPage)"
                shelf = book.shelf
            }
        }
    }
}
