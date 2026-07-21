# Biquge

苹果原生版笔趣阁 App，纯 SwiftUI + Swift 构建，支持 legado（开源「阅读」App）书源格式。

**你没有 Mac 也没关系** — 本项目配置了 GitHub Actions CI，push 后自动在云上编译产出 `.ipa`，你直接下载侧载到 iPhone 即可。

---

## 立即使用（无需 Mac）

### 第 1 步：从 GitHub Actions 下载编译好的 .ipa

1. 打开本仓库的 [Actions 页面](https://github.com/jz-my-code/biquge/actions)
2. 点击最新一次成功的 workflow run
3. 在底部 **Artifacts** 区下载 `Biquge-unsigned-ipa.zip`
4. 解压得到 `Biquge-unsigned.ipa`

### 第 2 步：侧载到 iPhone

需要侧载工具签到你的个人信息 Apple ID（Apple 的免费限制：7 天有效期，3 个 App）：

| 工具 | 平台 | 操作 |
|------|------|------|
| [Sideloadly](https://sideloadly.io) | Windows | 手机连电脑，拖 .ipa 进去，填 Apple ID 签名安装 |
| [AltStore](https://altstore.io) | Windows | 装 AltServer → 手机连电脑 → 导入 .ipa |
| [SideStore](https://sidestore.io) | Windows | 类似 AltStore，支持无线续签 |

> **注意**：.ipa 是未签名的，侧载工具会自动用你的 Apple ID 重新签名然后安装。

---

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

## 如果你有 Mac

```bash
git clone https://github.com/jz-my-code/biquge.git
cd biquge
open Package.swift   # Xcode 自动拉 SwiftSoup 依赖，Cmd+R 跑
```

或者用 XcodeGen（推荐，让 Actions 和本地行为一致）：

```bash
brew install xcodegen
xcodegen generate
open Biquge.xcodeproj
```

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
- 编译出的 .ipa 是未签名的，需要自己用 Apple ID 侧载

## 许可

个人学习用途。请勿用于商业发行或侵犯版权的传播。