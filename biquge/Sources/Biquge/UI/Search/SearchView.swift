import SwiftUI

// MARK: - 搜索页

/// 用户输入关键词 → 取所有启用的书源 → 并发搜索 → 合并结果
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sources: SourceStore
    @EnvironmentObject private var shelf: ShelfStore

    @State private var keyword: String = ""
    @State private var results: [SearchResult] = []
    @State private var loading = false
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                contentList
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - 子视图

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("书名或作者", text: $keyword)
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
                .autocorrectionDisabled()
            if !keyword.isEmpty {
                Button { keyword = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var contentList: some View {
        if loading {
            ProgressView("正在搜索…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = errorMsg {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle").font(.title)
                Text(err).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle").font(.system(size: 56)).foregroundStyle(.secondary)
                Text(keyword.isEmpty ? "输入关键词开始搜索" : "没有结果")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { r in
                NavigationLink(value: r.bookUrl) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.name).font(.headline).lineLimit(1)
                            Text(r.author).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            if let lc = r.lastChapter {
                                Text("最新：\(lc)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(r.sourceName).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: String.self) { bookUrl in
                ProgressView("加载中…")
                    .task { await loadThenNavigate(bookUrl: bookUrl, sourceId: results.first(where: { $0.bookUrl == bookUrl })?.sourceId ?? "") }
            }
        }
    }

    // MARK: - 业务

    private func search() async {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        loading = true
        errorMsg = nil
        results = []
        defer { loading = false }

        let enabled = sources.enabledSources()
        let resultsArray = await withTaskGroup(of: [SearchResult]?.self, returning: [SearchResult].self) { group in
            for source in enabled {
                group.addTask { [source] in
                    let repo = SourceRepository(source: source)
                    return (try? await repo.search(keyword: kw)) ?? nil
                }
            }
            var all: [SearchResult] = []
            for await r in group {
                if let arr = r { all.append(contentsOf: arr) }
            }
            return all
        }
        results = resultsArray
    }

    private func loadThenNavigate(bookUrl: String, sourceId: String) async {
        guard let source = sources.source(for: sourceId) else { return }
        let repo = SourceRepository(source: source)
        if let book = try? await repo.bookDetail(bookUrl: bookUrl) {
            // 通过关闭 sheet 后跳详情的简单方案：先保存到内存里供外层使用
            // 这里直接由 DetailView 接管渲染
            pendingBook = book
        }
    }

    @State private var pendingBook: Book?
}