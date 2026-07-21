import Foundation

// MARK: - 书源 HTTP 客户端

/// 负责用书源发起请求、返回 HTML 字符串
/// 处理：编码探测（GBK 优先）、UA、超时、基础 header

enum SourceClientError: Error {
    case invalidUrl
    case requestFailed(status: Int)
    case decodingFailed
    case emptyBody
}

struct SourceClient {
    let source: BookSource
    let session: URLSession

    init(source: BookSource, session: URLSession = .shared) {
        self.source = source
        self.session = session
    }

    // MARK: - Public

    /// 搜索请求
    func search(keyword: String) async throws -> String {
        guard let template = source.searchUrl else { throw SourceClientError.invalidUrl }
        let url = template.replacingOccurrences(of: "{{key}}", with: encodeQuery(keyword))
        return try await fetchRaw(urlString: url)
    }

    /// 分类浏览请求
    func explore(path: String) async throws -> String {
        guard let base = URL(string: source.bookSourceUrl.cleanBaseUrl) else { throw SourceClientError.invalidUrl }
        let url = base.appendingPathComponent(path).absoluteString
        return try await fetchRaw(urlString: url)
    }

    /// 任意 URL（详情页/章节页）
    func fetch(urlString: String) async throws -> String {
        try await fetchRaw(urlString: urlString)
    }

    // MARK: - Private

    private func fetchRaw(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw SourceClientError.invalidUrl }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.timeoutInterval = 15

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SourceClientError.requestFailed(status: -1) }
        guard (200..<400).contains(http.statusCode) else {
            throw SourceClientError.requestFailed(status: http.statusCode)
        }
        guard !data.isEmpty else { throw SourceClientError.emptyBody }

        // 优先按 Content-Type charset 解码；fallback GBK / UTF-8
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        if let charset = parseCharset(contentType), let s = decode(data: data, charset: charset) {
            return s
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let gbk = decode(data: data, charset: "gbk") { return gbk }
        throw SourceClientError.decodingFailed
    }

    private func parseCharset(_ contentType: String) -> String? {
        let lower = contentType.lowercased()
        guard let r = lower.range(of: "charset=") else { return nil }
        let rest = lower[r.upperBound...]
        let stop = rest.firstIndex(where: { $0 == ";" || $0 == " " || $0 == "\n" }) ?? rest.endIndex
        return String(rest[..<stop])
    }

    private func decode(data: Data, charset: String) -> String? {
        let encoding: String.Encoding
        switch charset.lowercased() {
        case "utf-8", "utf8": encoding = .utf8
        case "gbk", "gb2312", "gb18030":
            // CFStringEncoding → NSStringEncoding
            let cf = CFStringConvertIANACharSetNameToEncoding(charset.lowercased() as CFString)
            let ns = CFStringConvertEncodingToNSStringEncoding(cf)
            guard ns != kCFStringEncodingInvalidId else { return nil }
            encoding = String.Encoding(rawValue: ns)
        default:
            return nil
        }
        return String(data: data, encoding: encoding)
    }

    private func encodeQuery(_ s: String) -> String {
        // legado searchUrl 模板用 {{key}} 表示搜索词，一般直接 URL 编码
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}

// MARK: - URL 工具

extension String {
    /// 去掉书源 URL 中的 `#pb1101` 标签，得到真实 baseUrl
    var cleanBaseUrl: String {
        if let i = self.firstIndex(of: "#") {
            return String(self[..<i])
        }
        return self
    }
}