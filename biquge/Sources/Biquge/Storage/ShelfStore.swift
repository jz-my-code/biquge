import Foundation

// MARK: - 书架存储 + 阅读进度

/// ShelfItem 是书架上一本书的持久化状态
struct ShelfItem: Codable, Hashable, Identifiable {
    var id: String { bookId }
    let bookId: String
    let sourceId: String
    var addedAt: TimeInterval
    var lastReadAt: TimeInterval?
    var lastChapterUrl: String?
    var lastChapterTitle: String?

    init(book: Book) {
        self.bookId = book.id
        self.sourceId = book.sourceId
        self.addedAt = Date().timeIntervalSince1970
        self.lastReadAt = nil
        self.lastChapterUrl = nil
        self.lastChapterTitle = nil
    }
}

/// 阅读进度
struct ReadingProgress: Codable, Hashable {
    let bookId: String
    let chapterUrl: String
    let chapterTitle: String
    let chapterIndex: Int
    /// 翻页位置：当前章节面的页数/百分比
    var page: Int
    var totalPages: Int
    var chapterContentSha: String?
}

@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published private(set) var items: [ShelfItem] = []

    private let file: URL
    private let progressFile: URL

    private init() {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Biquge", isDirectory: true)
        self.file = dir.appendingPathComponent("shelf.json")
        self.progressFile = dir.appendingPathComponent("progress.json")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        loadAll()
    }

    // MARK: - 书架操作

    func add(_ book: Book) {
        if let i = items.firstIndex(where: { $0.bookId == book.id }) {
            items[i] = ShelfItem(book: book)
        } else {
            items.append(ShelfItem(book: book))
        }
        saveAll()
    }

    func remove(bookId: String) {
        items.removeAll { $0.bookId == bookId }
        saveAll()
    }

    func isOnShelf(bookId: String) -> Bool {
        items.contains { $0.bookId == bookId }
    }

    // MARK: - 进度操作

    func saveProgress(_ progress: ReadingProgress) {
        var all = loadProgressDict()
        all[progress.bookId] = progress
        if let i = items.firstIndex(where: { $0.bookId == progress.bookId }) {
            items[i].lastReadAt = Date().timeIntervalSince1970
            items[i].lastChapterUrl = progress.chapterUrl
            items[i].lastChapterTitle = progress.chapterTitle
        }
        saveProgressDict(all)
        saveAll()
    }

    func progress(for bookId: String) -> ReadingProgress? {
        loadProgressDict()[bookId]
    }

    // MARK: - I/O

    private func loadAll() {
        items = (try? JSONDecoder().decode([ShelfItem].self, from: Data(contentsOf: file))) ?? []
    }

    private func saveAll() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: file, options: .atomic)
    }

    private func loadProgressDict() -> [String: ReadingProgress] {
        (try? JSONDecoder().decode([String: ReadingProgress].self, from: Data(contentsOf: progressFile))) ?? [:]
    }

    private func saveProgressDict(_ dict: [String: ReadingProgress]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: progressFile, options: .atomic)
    }
}