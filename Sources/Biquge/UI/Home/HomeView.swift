import SwiftUI

// MARK: - 书架页

/// 显示 ShelfStore.items，点击进入详情
/// 顶端有搜索入口快捷按钮
struct HomeView: View {
    @EnvironmentObject private var shelf: ShelfStore
    @EnvironmentObject private var sources: SourceStore

    @State private var items: [ShelfItem] = []
    @State private var loadedBooks: [String: Book] = [:]
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if items.isEmpty {
                    emptyHint
                } else {
                    LazyVGrid(columns: gridCols, spacing: 16) {
                        ForEach(items) { item in
                            BookCardView(book: loadedBooks[item.bookId])
                                .onTapGesture { /* 跳详情由 NavigationLink 处理 */ }
                                .background(
                                    NavigationLink(value: item.bookId) { EmptyView() }
                                        .opacity(0)
                                )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(for: String.self) { bookId in
                if let book = loadedBooks[bookId] {
                    BookDetailView(book: book)
                } else {
                    ProgressView("加载中…")
                        .task { await loadBookMeta(bookId: bookId) }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .task { await refresh() }
            .onReceive(shelf.$items) { _ in Task { await refresh() } }
        }
    }

    // MARK: - 子视图

    private var gridCols: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("书架空空如也")
                .font(.headline)
            Text("从发现或搜索里加入书籍")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 数据

    private func refresh() async {
        items = shelf.items.sorted { (a, b) -> Bool in
            (b.lastReadAt ?? b.addedAt) > (a.lastReadAt ?? a.addedAt)
        }
        // 读取每本书的元信息（先从缓存，再 fallback 到补抓详情）
        for item in items where loadedBooks[item.bookId] == nil {
            await loadBookMeta(bookId: item.bookId)
        }
    }

    private func loadBookMeta(bookId: String) async {
        guard let sourceId = shelf.items.first(where: { $0.bookId == bookId })?.sourceId,
              let source = sources.source(for: sourceId) else { return }
        let repo = SourceRepository(source: source)
        if let book = try? await repo.bookDetail(bookUrl: bookId) {
            loadedBooks[bookId] = book
        }
    }
}

// MARK: - 书籍卡片

struct BookCardView: View {
    let book: Book?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
            Text(book?.name ?? "加载中…")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(book?.author ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var cover: some View {
        let size: CGFloat = 110
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
            if let url = book?.coverUrl, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else if phase.error != nil {
                        bookPlaceholder
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: size, height: size * 1.4)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                bookPlaceholder
                    .frame(width: size, height: size * 1.4)
            }
        }
    }

    private var bookPlaceholder: some View {
        VStack {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }
}