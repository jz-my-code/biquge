import Foundation
import SwiftSoup

// MARK: - 规则求值器（在真实 HTML 上执行 Pipeline）

/// 输入：原始 HTML + 一条规则字符串
/// 输出：解析后的字符串 / 字符串数组 / 元素列表
///
/// legado 规则在「list」场景下：bookList/chapterList 这类规则返回多个元素；
/// 在「single」场景下：name/author/intro 这类规则返回一个字符串。
/// 我们用 `evaluateList` 和 `evaluateSingle` 区分这两种语义。

struct RuleEvaluator {

    // MARK: - 单值求值（用于 name / author / intro / url 等）

    static func evaluateSingle(html: String, rule raw: String, baseUrl: String? = nil) -> String? {
        let pipeline = RuleParser.parse(raw)
        guard !pipeline.isEmpty else { return nil }

        do {
            let doc = try SwiftSoup.parse(html, baseUrl)
            return try runSingle(doc, pipeline: pipeline)
        } catch {
            print("[RuleEvaluator] single error: \(error) | rule=\(raw)")
            return nil
        }
    }

    // MARK: - 列表求值（用于 bookList / chapterList）

    /// 返回每个匹配元素的 outerHtml，调用方再用子规则在子树上求值
    static func evaluateList(rawHtml: String, rule raw: String) -> [String] {
        let pipeline = RuleParser.parse(raw)
        guard !pipeline.isEmpty else { return [] }

        do {
            let doc = try SwiftSoup.parse(rawHtml)
            let nodes = try runList(doc, pipeline: pipeline)
            return nodes.compactMap { try? $0.outerHtml() }
        } catch {
            print("[RuleEvaluator] list error: \(error) | rule=\(raw)")
            return []
        }
    }

    /// 在已切出的子树 HTML 上求值单值（避免重新 parse 整个文档）
    static func evaluateSingleInFragment(html fragment: String, rule raw: String, baseUrl: String? = nil) -> String? {
        let pipeline = RuleParser.parse(raw)
        guard !pipeline.isEmpty else { return nil }
        do {
            let doc = try SwiftSoup.parse(fragment, baseUrl)
            return try runSingle(doc, pipeline: pipeline)
        } catch {
            return nil
        }
    }

    // MARK: - 核心执行

    /// 单值：pipeline 跑到末尾，最后一步若是 text/html/attr 提取字符串，否则取首元素的 outerHtml
    private static func runSingle(_ root: Element, pipeline: RulePipeline) throws -> String? {
        var current: Element = root

        for (i, step) in pipeline.steps.enumerated() {
            let isLast = (i == pipeline.steps.count - 1)

            // text / html / attr 是「提取器」，遇到即终止
            if step.method == .text {
                let s = try current.text()
                return applyPostProcessors(s, processors: pipeline.postProcessors)
            }
            if step.method == .html {
                let s = try current.html()
                return applyPostProcessors(s, processors: pipeline.postProcessors)
            }
            if step.method == .attr {
                let s = try current.attr(step.value)
                return applyPostProcessors(s, processors: pipeline.postProcessors)
            }

            // 选择器步骤，前进 current
            let next = try step match(in: current)
            if next.isEmpty {
                return nil
            }
            let picked = pickIndex(from: next, step: step)
            guard let el = picked else { return nil }

            // 如果是最后一步但没遇到 text/html/attr，返回 outerHtml
            if isLast {
                let s = try el.outerHtml()
                return applyPostProcessors(s, processors: pipeline.postProcessors)
            }
            current = el
        }
        return nil
    }

    /// 列表：pipeline 大多数只有 1~2 步，最后一步返回元素列表
    private static func runList(_ root: Element, pipeline: RulePipeline) throws -> [Element] {
        var current: Element = root
        for (i, step) in pipeline.steps.enumerated() {
            let isLast = (i == pipeline.steps.count - 1)
            let matched = try step.match(in: current)
            if matched.isEmpty { return [] }

            if isLast {
                var result = matched
                if step.skipFirst > 0 {
                    result = Array(result.dropFirst(step.skipFirst))
                }
                return result
            }
            // 中间步骤默认取第一个继续
            guard let next = matched.first else { return [] }
            current = next
        }
        return []
    }

    // MARK: - 索引取值

    private static func pickIndex(from nodes: [Element], step: SelectorStep) -> Element? {
        var arr = nodes
        if step.skipFirst > 0 {
            arr = Array(arr.dropFirst(step.skipFirst))
        }
        if let idx = step.index {
            return arr.indices.contains(idx) ? arr[idx] : nil
        }
        return arr.first
    }

    // MARK: - 后处理器应用

    static func applyPostProcessors(_ input: String, processors: [PostProcessor]) -> String {
        var s = input
        for p in processors {
            s = applyOne(s, processor: p)
        }
        return s
    }

    private static func applyOne(_ input: String, processor: PostProcessor) -> String {
        switch processor.type {
        case .metadata:
            return input
        case .regexRemove:
            // 单条正则 → 移除匹配部分
            if let re = try? NSRegularExpression(pattern: processor.pattern, options: []) {
                let range = NSRange(location: 0, length: input.utf16.count)
                let result = re.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
                return result
            }
            return input
        case .regexMulti:
            // 多个正则用 | 分隔，逐个移除
            let subs = processor.pattern.split(separator: "|", omittingEmptySubsequences: false)
            var s = input
            for sub in subs {
                let pat = String(sub)
                if let re = try? NSRegularExpression(pattern: pat, options: []) {
                    let range = NSRange(location: 0, length: s.utf16.count)
                    s = re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
                }
            }
            return s
        }
    }
}

// MARK: - SelectorStep 求值扩展

extension SelectorStep {
    /// 在父元素下执行本步骤，返回匹配到的元素列表
    func match(in parent: Element) throws -> [Element] {
        switch method {
        case .tag:
            return try parent.select(value).array()
        case .id:
            return try parent.select("#\(value)").array()
        case .className:
            return try parent.select(".\(value)").array()
        case .text, .html, .attr:
            return [parent] // 提取器步骤，不前进
        }
    }
}