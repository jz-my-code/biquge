# Biquge

苹果原生版笔趣阁 App，纯 SwiftUI + Swift 构建，支持 legado（开源「阅读」App）书源格式。

## 项目特点

- **书源驱动**：不绑定单站，单站挂了换源即可，App 不报废
- **legado 规则引擎**：实现了 `@/tag./id./class./##正则/@text/@html/@src/@href` 选择器与后处理器
- **纯原生**：SwiftUI + Swift，iOS 16+，支持 iPhone / iPad
- **本地缓存**：章节正文缓存到 Application Support，离线续读
- **现代化阅读体验**：日/夜模式、字体大小、行距、滑动翻页、章节数导航

## 项目结构

```
Sources/Biquge/
├── Models/                  数据模型
│   ├── BookSource.swift     legado 书源 JSON 模型
│   └── Book.swift           Book / Chapter / SearchResult 等
├── RuleEngine/              规则引擎
│   ├── RuleParser.swift     选择器语法解析
│   └── RuleEvaluator.swift  在 HTML 上执行规则
├── Network/
│   └── SourceClient.swift   HTTP 客户端（GBK/UTF-8 自动识别）
├── Repository/
│   └── SourceRepository.swift  搜索/详情/目录/正文 业务封装
├── Storage/
│   ├── SourceStore.swift    书源持久化 + 章节缓存
│   └── ShelfStore.swift     书架 + 阅读进度
├── Resources/
│   └── default_book_source.json  内置笔趣阁源
└── UI/
    ├── Root/BiqugeApp.swift        App 入口 / TabView
    ├── Home/HomeView.swift         书架
    ├── Search/SearchView.swift     搜索
    ├── Detail/BookDetailView.swift 详情 + 目录
    ├── Reader/ReaderView.swift     阅读器
    ├── Explore/ExploreView.swift   分类发现
    └── SourceManager/SourceManagerView.swift  书源管理
```

## 数据流

```
┌────────────┐    解析     ┌──────────────┐
│ BookSource │ ─────────▶ │ RuleParser    │
└─────┬──────┘            │ RuleEvaluator │
      │                   └──────┬───────┘
      ▼                          │
┌──────────────┐  发请求          │
│ SourceClient │ ──── HTML ──────┘
└─────┬────────┘
      ▼
┌──────────────────┐  模型   ┌────────────┐
│ SourceRepository │ ──────▶ │ SwiftUI UI │
└──────────────────┘         └────────────┘
```

## 如何运行

1. **拷到 Mac**：把整个 `biquge/` 目录拷到 macOS
2. **用 Xcode 打开**：`open Package.swift`（用 SwiftPM 方式打开，会自动拉取 SwiftSoup 依赖）
3. **真机调试**：选 iPhone 模拟器或真机，Cmd+R 即可

> Windows 上无法编译 iOS 项目，源代码写完后必须在 Xcode 上构建。

## 使用方法

1. **首次启动**：内置笔趣阁源已加载，可直接搜索/分类浏览
2. **加书源**：到「书源」标签 → 右上角「+」→ 粘贴书源 JSON
3. **搜书**：书架页右上角放大镜 → 输入关键词
4. **阅读**：点章节进入阅读器，左右滑切换上下章，点屏幕中央唤出工具栏
5. **加入书架**：详情页右上角书签按钮

## 依赖

- [SwiftSoup](https://github.com/scinfu/SwiftSoup) 2.7+：HTML 解析与 CSS 选择器求值

## 已知限制 / TODO

- 未实现 `<js>...</js>` 内联 JS（legado 部分高级源会用到），后续可用 JavaScriptCore 补
- 仅实现了 legado 规则的基础语法，复杂多级规则可能需要扩展 RuleEvaluator
- 未做章节预加载（下章缓存）
- 未做书源在线导入（粘贴 URL 抓书源 JSON）
- 阅读器仅做滚动模式，未做翻页
- 未做 TTS 朗读

## 许可

个人学习用途。请勿用于商业发行或侵犯版权的传播。