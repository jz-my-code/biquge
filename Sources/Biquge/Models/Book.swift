import Foundation

// MARK: - 领域模型

/// 书籍（来自书源解析结果 / 书架持久化）
struct Book: Identifiable, Hashable {
    let id: String          // 详情页 URL，全局唯一
    let sourceId: String    // 所属书源 bookSourceUrl
    let name: String
    let author: String
    let coverUrl: String?
    let intro: String?
    let kind: String?       // 分类 / 最后更新标签
    let lastChapter: String?

    init(id: String, sourceId: String, name: String, author: String,
         coverUrl: String? = nil, intro: String? = nil,
         kind: String? = nil, lastChapter: String? = nil) {
        self.id = id
        self.sourceId = sourceId
        self.name = name
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
    }
}

/// 章节
struct Chapter: Identifiable, Hashable {
    let id: String      // 章节页 URL
    let bookId: String  // 所属书籍 URL
    let title: String
    let index: Int
}

/// 搜索结果条目
struct SearchResult: Identifiable, Hashable {
    let id: String
    let sourceId: String
    let sourceName: String
    let name: String
    let author: String
    let bookUrl: String
    let lastChapter: String?
}

/// 分类浏览条目
struct ExploreResult: Identifiable, Hashable {
    let id: String
    let name: String
    let author: String
    let bookUrl: String
    let lastChapter: String?
}