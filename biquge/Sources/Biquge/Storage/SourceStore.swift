import Foundation

// MARK: - 书源仓库（本地持久化）

/// 纯文件持久化，目录：Application Support/Biquge/
///   sources.json   → 书源列表
///   shelf.json     → 书架（已加入的书）
///   progress.json  → 阅读进度
///   chapters/<sha>.txt → 章节正文缓存

@MainActor
final class SourceStore: ObservableObject {

    static let shared = SourceStore()

    @Published private(set) var sources: [BookSource] = []

    private let dir: URL
    private let sourcesFile: URL

    private init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let root = support ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Biquge", isDirectory: true)
        self.dir = root
        self.sourcesFile = root.appendingPathComponent("sources.json", isDirectory: false)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        // 子目录
        try? fm.createDirectory(at: root.appendingPathComponent("chapters", isDirectory: true), withIntermediateDirectories: true)

        loadAll()
        if sources.isEmpty {
            sources = [Self.bundledDefault]
            saveAll()
        }
    }

    // MARK: - 公开 API

    func add(source: BookSource) {
        if let i = sources.firstIndex(where: { $0.id == source.id }) {
            sources[i] = source
        } else {
            sources.append(source)
        }
        saveAll()
    }

    func remove(sourceId: String) {
        sources.removeAll { $0.id == sourceId }
        saveAll()
    }

    func setEnabled(sourceId: String, enabled: Bool) {
        guard let i = sources.firstIndex(where: { $0.id == sourceId }) else { return }
        var s = sources[i]
        // BookSource 是 let，替换整对象
        let data = try? JSONEncoder().encode(s)
        guard var dict = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) else { return }
        dict["enabled"] = enabled
        if let newData = try? JSONSerialization.data(withJSONObject: dict),
           let newSource = try? JSONDecoder().decode(BookSource.self, from: newData) {
            sources[i] = newSource
            saveAll()
        }
        _ = s // silence
    }

    func enabledSources() -> [BookSource] { sources.filter { $0.enabled } }

    func source(for id: String) -> BookSource? { sources.first { $0.id == id } }

    // MARK: - 内置默认源

    static let bundledDefault: BookSource = {
        guard let url = Bundle.main.url(forResource: "default_book_source", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let source = try? JSONDecoder().decode(BookSource.self, from: data) else {
            // 开发期 fallback：直接构造空对象（legado 解码失败时给空源占位）
            return BookSource(
                bookSourceName: "fallback",
                bookSourceUrl: "fallback://",
                bookSourceGroup: nil, bookSourceComment: nil, bookSourceType: 0,
                bookUrlPattern: nil, customOrder: 0, enabled: true,
                enabledCookieJar: false, enabledExplore: false,
                exploreUrl: nil, lastUpdateTime: nil, loginUrl: nil,
                respondTime: nil, weight: 0, searchUrl: nil,
                ruleBookInfo: nil, ruleContent: nil, ruleExplore: nil,
                ruleSearch: nil, ruleToc: nil
            )
        }
        return source
    }()

    // MARK: - 文件 I/O

    private func loadAll() {
        guard let data = try? Data(contentsOf: sourcesFile),
              let arr = try? JSONDecoder().decode([BookSource].self, from: data) else { return }
        sources = arr
    }

    private func saveAll() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: sourcesFile)
    }

    // MARK: - 章节缓存

    func cachedChapter(bookId: String, chapterUrl: String) -> String? {
        let f = chapterCacheFile(bookId: bookId, chapterUrl: chapterUrl)
        return try? String(contentsOf: f, encoding: .utf8)
    }

    func saveChapterCache(content: String, bookId: String, chapterUrl: String) {
        let f = chapterCacheFile(bookId: bookId, chapterUrl: chapterUrl)
        try? content.write(to: f, atomically: true, encoding: .utf8)
    }

    private func chapterCacheFile(bookId: String, chapterUrl: String) -> URL {
        let key = sha(bookId + "|" + chapterUrl)
        return dir.appendingPathComponent("chapters", isDirectory: true).appendingPathComponent("\(key).txt", isDirectory: false)
    }

    private func sha(_ s: String) -> String {
        // 简易 hash（不要求密码学强度，仅做文件名）
        return String(format: "%016llx", s.hashValue & 0xFFFFFFFFFFFFFFFF)
    }
}