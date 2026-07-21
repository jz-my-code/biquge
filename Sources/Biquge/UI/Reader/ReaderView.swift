import SwiftUI

// MARK: - 阅读器

/// 核心阅读体验：分页、字体大小、日/夜模式、翻页
/// 支持章节导航、进度保存
struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sources: SourceStore
    @EnvironmentObject private var shelf: ShelfStore

    let bookId: String
    @State private var currentChapter: Chapter

    @State private var content: String = ""
    @State private var loading = true
    @State private var chapters: [Chapter] = []
    @State private var currentIndex: Int = 0

    @AppStorage("reader.fontSize") private var fontSize: Double = 20
    @AppStorage("reader.darkMode") private var darkMode = false
    @AppStorage("reader.lineSpacing") private var lineSpacing: Double = 6

    init(bookId: String, chapter: Chapter) {
        self.bookId = bookId
        _currentChapter = .init(initialValue: chapter)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 正文区域
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底部工具栏
            toolBar
        }
        .preferredColorScheme(darkMode ? .dark : nil)
        .background(backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Text(currentChapter.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await loadChapter(chapter: currentChapter) }
    }

    // MARK: - 正文区域

    @ViewBuilder
    private var contentView: some View {
        if loading {
            ProgressView("加载章节…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if content.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.page.slash").font(.title)
                Text("章节内容为空")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                Text(content)
                    .font(.system(size: fontSize))
                    .lineSpacing(lineSpacing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { showTools.toggle() } }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { gesture in
                        let dx = gesture.translation.width
                        if dx < -60 {
                            nextChapter()
                        } else if dx > 60 {
                            prevChapter()
                        }
                    }
            )
        }
    }

    @State private var showTools = true

    // MARK: - 工具栏

    private var toolBar: some View {
        VStack(spacing: 8) {
            // 字体大小调节
            HStack(spacing: 12) {
                Button { fontSize = max(12, fontSize - 2) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                Slider(value: $fontSize, in: 12...32, step: 1)
                    .tint(.orange)
                Button { fontSize = min(32, fontSize + 2) } label: {
                    Image(systemName: "textformat.size.larger")
                }
            }
            .padding(.horizontal)

            // 章节导航
            HStack(spacing: 20) {
                Button("上一章") { prevChapter() }
                    .disabled(currentIndex <= 0)

                Button("日/夜") {
                    withAnimation { darkMode.toggle() }
                }
                .foregroundStyle(darkMode ? .orange : .secondary)

                Button("下一章") { nextChapter() }
                    .disabled(currentIndex >= chapters.count - 1)
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - 动作

    private func prevChapter() {
        guard currentIndex > 0 else { return }
        let idx = currentIndex - 1
        currentIndex = idx
        currentChapter = chapters[idx]
        Task { await loadChapter(chapter: currentChapter) }
    }

    private func nextChapter() {
        guard currentIndex < chapters.count - 1 else { return }
        let idx = currentIndex + 1
        currentIndex = idx
        currentChapter = chapters[idx]
        Task { await loadChapter(chapter: currentChapter) }
    }

    private func loadChapter(chapter: Chapter) async {
        loading = true
        content = ""
        defer { loading = false }

        // 先查缓存
        if let cached = SourceStore.shared.cachedChapter(bookId: bookId, chapterUrl: chapter.id) {
            content = cached
            return
        }

        // 从书源抓取
        guard let srcId = shelf.items.first(where: { $0.bookId == bookId })?.sourceId,
              let source = sources.source(for: srcId) else { return }
        let repo = SourceRepository(source: source)
        do {
            let text = try await repo.chapterContent(chapterUrl: chapter.id)
            content = text
            SourceStore.shared.saveChapterCache(content: text, bookId: bookId, chapterUrl: chapter.id)

            // 保存阅读进度
            let progress = ReadingProgress(
                bookId: bookId,
                chapterUrl: chapter.id,
                chapterTitle: chapter.title,
                chapterIndex: chapter.index,
                page: 0,
                totalPages: 0
            )
            shelf.saveProgress(progress)
        } catch {
            content = "加载失败：\(error.localizedDescription)"
        }

        // 拉取完整目录（如果还没拉的话）
        if chapters.isEmpty {
            if let source = sources.source(for: srcId) {
                let repo = SourceRepository(source: source)
                if let toc = try? await repo.tableOfContents(bookUrl: bookId) {
                    chapters = toc
                    currentIndex = toc.firstIndex(where: { $0.id == chapter.id }) ?? 0
                }
            }
        }
    }

    // MARK: - 样式

    private var backgroundColor: Color {
        darkMode ? Color(red: 0.08, green: 0.08, blue: 0.1) : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var textColor: Color {
        darkMode ? Color(red: 0.85, green: 0.84, blue: 0.82) : Color(red: 0.15, green: 0.15, blue: 0.15)
    }
}