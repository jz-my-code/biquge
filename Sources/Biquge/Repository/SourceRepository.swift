import Foundation

// MARK: - 书源业务仓库

/// 对外暴露的 4 个核心业务：
///   - search(keyword) → 搜索
///   - explore(category) → 分类
///   - bookDetail(bookUrl) → 详情（含目录）
///   - chapterContent(chapterUrl) → 正文
///
/// 设计原则：单一数据流向
///   BookSource → SourceClient → HTML → RuleEvaluator → Domain Model

struct SourceRepository {
    let source: BookSource
    let client: SourceClient

    init(source: BookSource) {
        self.source = source
        self.client = SourceClient(source: source)
    }

    // MARK: - 搜索

    func search(keyword: String) async throws -> [SearchResult] {
        let html = try await client.search(keyword: keyword)
        guard let searchRule = source.ruleSearch,
              let bookListRule = searchRule.bookList else { return [] }

        let fragments = RuleEvaluator.evaluateList(rawHtml: html, rule: bookListRule)
        return fragments.compactMap { fragment -> SearchResult? in
            guard let name = RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: searchRule.name ?? "") else {
                return nil
            }
            let bookUrl = (RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: searchRule.bookUrl ?? "") ?? "")
                .components(separatedBy: "$##")[0]     // 去掉 ##$##,{"webView":true} 这类元数据尾巴
            guard !bookUrl.isEmpty else { return nil }

            return SearchResult(
                id: bookUrl,
                sourceId: source.id,
                sourceName: source.bookSourceName,
                name: name,
                author: RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: searchRule.author ?? "") ?? "",
                bookUrl: bookUrl,
                lastChapter: RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: searchRule.lastChapter ?? "")
            )
        }
    }

    // MARK: - 分类浏览

    func exploreEntries() -> [ExploreEntry] {
        guard let raw = source.exploreUrl, !raw.isEmpty else { return [] }
        return raw
            .split(separator: "\n")
            .compactMap { line -> ExploreEntry? in
                let parts = line.split(separator: "::", omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                return ExploreEntry(name: String(parts[0]), path: String(parts[1]).trimmingCharacters(in: .whitespaces))
            }
    }

    func explore(path: String) async throws -> [ExploreResult] {
        let html = try await client.explore(path: path)
        guard let rule = source.ruleExplore,
              let bookListRule = rule.bookList else { return [] }

        let fragments = RuleEvaluator.evaluateList(rawHtml: html, rule: bookListRule)
        return fragments.compactMap { fragment -> ExploreResult? in
            guard let name = RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.name ?? ""),
                  let bookUrl = RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.bookUrl ?? ""),
                  !bookUrl.isEmpty else { return nil }
            return ExploreResult(
                id: bookUrl,
                name: name,
                author: RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.author ?? "") ?? "",
                bookUrl: bookUrl,
                lastChapter: RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.lastChapter ?? "")
            )
        }
    }

    // MARK: - 详情

    func bookDetail(bookUrl: String) async throws -> Book {
        let html = try await client.fetch(urlString: bookUrl)
        let info = source.ruleBookInfo

        let name = info.flatMap { $0.name }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0, baseUrl: bookUrl) } ?? ""
        let author = info.flatMap { $0.author }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0) } ?? ""
        let cover = info.flatMap { $0.coverUrl }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0, baseUrl: bookUrl) }
        let intro = info.flatMap { $0.intro }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0) }
        let kind = info.flatMap { $0.kind }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0) }
        let lastChapter = info.flatMap { $0.lastChapter }.flatMap { RuleEvaluator.evaluateSingle(html: html, rule: $0) }

        return Book(
            id: bookUrl,
            sourceId: source.id,
            name: name,
            author: author,
            coverUrl: cover,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter
        )
    }

    // MARK: - 目录

    func tableOfContents(bookUrl: String) async throws -> [Chapter] {
        let html = try await client.fetch(urlString: bookUrl)
        guard let rule = source.ruleToc,
              let chapterListRule = rule.chapterList else { return [] }

        let fragments = RuleEvaluator.evaluateList(rawHtml: html, rule: chapterListRule)
        return fragments.enumerated().compactMap { (idx, fragment) in
            guard let title = RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.chapterName ?? ""),
                  let url = RuleEvaluator.evaluateSingleInFragment(html: fragment, rule: rule.chapterUrl ?? "", baseUrl: bookUrl),
                  !title.isEmpty, !url.isEmpty else { return nil }
            return Chapter(id: url, bookId: bookUrl, title: title, index: idx)
        }
    }

    // MARK: - 正文

    func chapterContent(chapterUrl: String) async throws -> String {
        let html = try await client.fetch(urlString: chapterUrl)
        guard let rule = source.ruleContent,
              let contentRule = rule.content else { return "" }

        let raw = RuleEvaluator.evaluateSingle(html: html, rule: contentRule, baseUrl: chapterUrl) ?? ""

        // 把 <br> 转成换行、去标签、合并多余空行
        return cleanContent(raw)
    }

    private func cleanContent(_ raw: String) -> String {
        var s = raw
        // <br> → \n
        s = s.replacingOccurrences(of: "<br/>", with: "\n")
        s = s.replacingOccurrences(of: "<br />", with: "\n")
        s = s.replacingOccurrences(of: "<br>", with: "\n")
        // 去 HTML 实体
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        // 折叠多余空行
        while s.contains("\n\n\n") {
            s = s.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 分类条目辅助模型

struct ExploreEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
}