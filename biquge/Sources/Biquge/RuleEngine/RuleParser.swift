import Foundation

// MARK: - legado 规则解析器

/// — 规则语法 —
///
/// 一条完整规则如：`id.info@tag.h1.0@text##作    者：`
///
/// 分段方式：
///   1. 按 `@@` 分割多组规则（暂只处理第一组）
///   2. 每组按 `@` 分割选择器链
///   3. 最后一个分段按 `##` 分隔出后处理器
///
/// 选择器类型：
///   tag.xxx   → CSS 标签选择器
///   id.xxx    → CSS ID 选择器 (#xxx)
///   class.xxx → CSS 类选择器 (.xxx)
///   text      → 取 textContent
///   html      → 取 innerHTML
///   @attr     → 取属性值 (@src / @href)
///   .N        → 取第 N 个元素（0-based）
///   !N        → 跳过前 N 个元素
///   ##正则     → 移除匹配正则的文本（多个用 | 分隔）
///   ##$##json → 元数据标记，不回写

struct RuleParser {

    /// 将规则字符串解析为可执行的 Pipeline
    static func parse(_ raw: String) -> RulePipeline {
        let rule = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty else { return .empty }

        // 只处理 @@ 的第一组
        let firstGroup = rule.components(separatedBy: "@@")
            .first ?? rule

        // 找到第一个 ## 作为选择器与后处理器的分界
        let selectorPart: String
        let processorParts: [String]
        if let hashRange = firstGroup.range(of: "##") {
            selectorPart = String(firstGroup[..<hashRange.lowerBound])
            let rest = String(firstGroup[hashRange.upperBound...])
            processorParts = [rest]
        } else {
            selectorPart = firstGroup
            processorParts = []
        }

        let segments = selectorPart.split(separator: "@", omittingEmptySubsequences: false)
        let steps = segments.compactMap { parseSegment(String($0)) }

        let processors: [PostProcessor] = processorParts.compactMap { pattern in
            guard !pattern.isEmpty else { return nil }
            if pattern.hasPrefix("$##") {
                return PostProcessor(pattern: pattern, type: .metadata)
            }
            let sub = pattern.split(separator: "|", omittingEmptySubsequences: false)
            if sub.count > 1 {
                return PostProcessor(pattern: pattern, type: .regexMulti)
            }
            return PostProcessor(pattern: pattern, type: .regexRemove)
        }

        return RulePipeline(steps: steps, postProcessors: processors)
    }

    // MARK: - 段落解析

    /// 解析单个 @ 分段
    /// "tag.dd.0!1" → method:.tag, value:"dd", index:0, skipFirst:1
    private static func parseSegment(_ raw: String) -> SelectorStep? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        switch true {
        case s == "text":
            return SelectorStep(method: .text, value: "")

        case s == "html":
            return SelectorStep(method: .html, value: "")

        case s.hasPrefix("@@"):
            return nil // 多组分隔，忽略

        case s.hasPrefix("@"):
            return SelectorStep(method: .attr, value: String(s.dropFirst()))

        case s.hasPrefix("tag."):
            return parseComplexSelector(s, strip: 4, fallback: .tag)

        case s.hasPrefix("id."):
            return parseComplexSelector(s, strip: 3, fallback: .id)

        case s.hasPrefix("class."):
            return parseComplexSelector(s, strip: 6, fallback: .className)

        default:
            // 裸标签名 → 当作 tag.xxx
            guard s.rangeOfCharacter(from: .letters) != nil else { return nil }
            return parseComplexSelector(s, strip: 0, fallback: .tag)
        }
    }

    /// 解析带 .N / !N 后缀的复杂选择器
    private static func parseComplexSelector(_ raw: String, strip prefixLen: Int, fallback method: SelectorMethod) -> SelectorStep {
        var value = prefixLen > 0 ? String(raw.dropFirst(prefixLen)) : raw
        var index: Int?
        var skipFirst = 0

        // !N 后缀（跳过前 N 个）
        if let bang = value.lastIndex(of: "!") {
            let num = value[value.index(after: bang)...]
            if let n = Int(String(num)) {
                skipFirst = n
                value = String(value[..<bang])
            }
        }

        // .N 后缀（取第 N 个）
        if let dot = value.lastIndex(of: ".") {
            let num = value[value.index(after: dot)...]
            if let n = Int(String(num)) {
                index = n
                value = String(value[..<dot])
            }
        }

        return SelectorStep(method: method, value: value, index: index, skipFirst: skipFirst)
    }
}

// MARK: - 基础类型

struct SelectorStep: Hashable {
    let method: SelectorMethod
    let value: String
    let index: Int?
    let skipFirst: Int
}

enum SelectorMethod: String, Hashable {
    case tag
    case id
    case className = "class"
    case text
    case html
    case attr
}

struct PostProcessor: Hashable {
    enum Kind: Hashable {
        case regexRemove   // 移除匹配文本
        case regexMulti    // 多个 | 分隔的正则移除
        case metadata      // ##$##... 元数据标记
    }
    let pattern: String
    let type: Kind
}

struct RulePipeline: Hashable {
    let steps: [SelectorStep]
    let postProcessors: [PostProcessor]

    static let empty = RulePipeline(steps: [], postProcessors: [])
    var isEmpty: Bool { steps.isEmpty && postProcessors.isEmpty }
}