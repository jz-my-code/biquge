import SwiftUI

// MARK: - 书籍详情页

/// 展示书名、作者、封面、简介、目录列表
/// 点击加入书架 / 点击章节进入阅读器
struct BookDetailView: View {
    @EnvironmentObject private var shelf: ShelfStore
    @EnvironmentObject private var sources: SourceStore

    let bookUrl: String
    let sourceId: String

    @State private var book: Book?
    @State private var chapters: [Chapter] = []
    @State private var loading = true
    @State private var error: String?

    init(bookUrl: String, sourceId: String) {
        self.bookUrl = bookUrl
        self.sourceId = sourceId
    }

    /// 快捷构造：从书架已知 book
    init(book: Book) {
        self.bookUrl = book.id
        self.sourceId = book.sourceId
        _book = .init(initialValue: book)
    }

    var body: some View {
        ScrollView {
            if loading {
                ProgressView("加载中…").padding(.top, 100)
            } else if let err = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.title)
                    Text(err).foregroundStyle(.secondary)
                }
                .padding(.top, 100)
            } else if let bk = book {
                VStack(alignment: .leading, spacing: 16) {
                    header(bk)
                    Divider()
                    chapterList
                }
                .padding()
            }
        }
        .navigationTitle(book?.name ?? "详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let bk = book {
                    Button {
                        if shelf.isOnShelf(bookId: bk.id) {
                            shelf.remove(bookId: bk.id)
                        } else {
                            shelf.add(bk)
                        }
                    } label: {
                        Image(systemName: shelf.isOnShelf(bookId: bk.id) ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
        .task { await load() }
    }

    // MARK: - 头部

    @ViewBuilder
    private func header(_ bk: Book) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                if let url = bk.coverUrl, let u = URL(string: url) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            Image(systemName: "book.closed").font(.title2).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "book.closed").font(.title2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 126)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(bk.name).font(.title3).fontWeight(.bold).lineLimit(2)
                Text(bk.author).font(.subheadline).foregroundStyle(.secondary)
                if let kind = bk.kind {
                    Text(kind).font(.caption).foregroundStyle(.tertiary)
                }
                if let lc = bk.lastChapter {
                    Text(lc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
        }

        if let intro = bk.intro {
            Text(intro)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.primary.opacity(0.85))
        }
    }

    // MARK: - 目录

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("目录（\(chapters.count) 章）")
                .font(.headline)
            if chapters.isEmpty {
                Text("目录加载失败")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(chapters) { ch in
                    NavigationLink(value: ch) {
                        HStack {
                            Text("第 \(ch.index + 1) 章")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 56, alignment: .leading)
                            Text(ch.title)
                                .font(.body)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationDestination(for: Chapter.self) { ch in
            ReaderView(bookId: bookUrl, chapter: ch)
        }
    }

    // MARK: - 加载

    private func load() async {
        guard let source = sources.source(for: sourceId) else {
            error = "书源未找到"
            loading = false
            return
        }
        let repo = SourceRepository(source: source)
        do {
            async let bk = repo.bookDetail(bookUrl: bookUrl)
            async let toc = repo.tableOfContents(bookUrl: bookUrl)
            book = try await bk
            chapters = try await toc
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Chapter + Hashable 协议满足 Navigation

extension Chapter: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bookId)
        hasher.combine(index)
    }

    static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.id == rhs.id && lhs.bookId == rhs.bookId && lhs.index == rhs.index
    }
}