import SwiftUI

// MARK: - 发现页（分类浏览）

/// 使用书源的 exploreUrl 分类列表，进入后展示书籍列表
struct ExploreView: View {
    @EnvironmentObject private var sources: SourceStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(sources.enabledSources()) { source in
                    if source.enabledExplore {
                        let entries = entries(for: source)
                        if !entries.isEmpty {
                            Section(source.bookSourceName) {
                                ForEach(entries) { entry in
                                    NavigationLink(value: ExploreTarget(sourceId: source.id, entry: entry)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.name)
                                                .font(.body)
                                            Text(source.bookSourceName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("发现")
            .navigationDestination(for: ExploreTarget.self) { target in
                ExploreBooksView(sourceId: target.sourceId, path: target.entry.path, title: target.entry.name)
            }
        }
    }

    private func entries(for source: BookSource) -> [ExploreEntry] {
        let repo = SourceRepository(source: source)
        return repo.exploreEntries()
    }
}

// MARK: - 导航目标

struct ExploreTarget: Identifiable, Hashable {
    let id = UUID()
    let sourceId: String
    let entry: ExploreEntry
}

// MARK: - 分类书籍列表

struct ExploreBooksView: View {
    @EnvironmentObject private var sources: SourceStore

    let sourceId: String
    let path: String
    let title: String

    @State private var books: [ExploreResult] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("加载中…")
            } else if let err = error {
                ContentUnavailableView("加载失败", systemImage: "exclamationmark.triangle", description: Text(err))
            } else if books.isEmpty {
                ContentUnavailableView("无数据", systemImage: "tray", description: Text("该分类暂无书籍"))
            } else {
                List(books) { book in
                    NavigationLink(value: book.bookUrl) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name).font(.headline).lineLimit(1)
                            HStack {
                                Text(book.author).font(.caption).foregroundStyle(.secondary)
                                if let lc = book.lastChapter {
                                    Text("· \(lc)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: String.self) { url in
                    BookDetailView(bookUrl: url, sourceId: sourceId)
                }
            }
        }
        .navigationTitle(title)
        .task { await load() }
    }

    private func load() async {
        guard let source = sources.source(for: sourceId) else {
            error = "书源未找到"
            loading = false
            return
        }
        let repo = SourceRepository(source: source)
        do {
            books = try await repo.explore(path: path)
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }
}