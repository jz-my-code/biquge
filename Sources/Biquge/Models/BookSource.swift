import Foundation

// MARK: - 书源模型（legado 格式）

/// 对应 legado「阅读」App 的书源 JSON 数据结构
struct BookSource: Identifiable, Codable, Hashable {
    var id: String { bookSourceUrl }

    let bookSourceName: String
    let bookSourceUrl: String
    let bookSourceGroup: String?
    let bookSourceComment: String?
    let bookSourceType: Int
    let bookUrlPattern: String?
    let customOrder: Int
    let enabled: Bool
    let enabledCookieJar: Bool
    let enabledExplore: Bool
    let exploreUrl: String?
    let lastUpdateTime: TimeInterval?
    let loginUrl: String?
    let respondTime: TimeInterval?
    let weight: Int?
    let searchUrl: String?

    let ruleBookInfo: BookInfoRule?
    let ruleContent: ContentRule?
    let ruleExplore: ExploreRule?
    let ruleSearch: SearchRule?
    let ruleToc: TocRule?

    // MARK: - 规则子模型

    struct BookInfoRule: Codable, Hashable {
        let author: String?
        let coverUrl: String?
        let intro: String?
        let kind: String?
        let lastChapter: String?
        let name: String?
    }

    struct ContentRule: Codable, Hashable {
        let content: String?
        let nextContentUrl: String?
    }

    struct ExploreRule: Codable, Hashable {
        let author: String?
        let bookList: String?
        let bookUrl: String?
        let lastChapter: String?
        let name: String?
    }

    struct SearchRule: Codable, Hashable {
        let author: String?
        let bookList: String?
        let bookUrl: String?
        let coverUrl: String?
        let lastChapter: String?
        let name: String?
    }

    struct TocRule: Codable, Hashable {
        let chapterList: String?
        let chapterName: String?
        let chapterUrl: String?
    }
}