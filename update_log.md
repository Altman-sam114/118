# 项目版本更新记录

本文记录项目正式版本、重要维护事项、关键决策和遗留问题。这里不是流水账，只记录会影响后续开发判断的事实。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新功能版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。
- Agent C 负责在验收阶段判断是否需要追加或修正本文件。
- Agent C 最终验收通过后必须按版本号创建 git 提交；验收不通过时记录问题并退回 Agent B，不创建提交。

## 当前状态

- 项目类型：原生 iOS SwiftUI + SwiftData 应用。
- 目标能力：管理 GGUF 模型，调用 stable-diffusion.cpp native backend，在本机完成图片生成、图库管理和提示词模板复用。
- 当前 UI：简洁暗色科幻风，核心共享样式集中在 `LocalDiffusion/Views/Shared/ParameterEditor.swift`。
- 当前 native 路径：`ImageGenerationBackend` 协议隔离，`USE_STABLE_DIFFUSION_CPP` 启用 stable-diffusion.cpp XCFramework。
- 当前验证入口：本地轻量检查、Swift 解析、native bridge 解析、`plutil`、`Scripts/check-native-backend.sh`、GitHub Actions `ci-results` 结果包、人工明确要求时的 `Scripts/smoke-test-simulator.sh` 和沙箱外 `xcodebuild`。
- 当前分支事实：当前使用 `main` 跟踪 `origin/main`；云端 CI 通过 GitHub Actions `Local Diffusion CI Results` 运行，Agent C 结果包缓存默认在 `/private/tmp/localdiffusion-c-review-<run_id>/`。

## 历史记录

### v0.1 / 初始 iOS 本地图像生成应用

- 日期：2026-06-10 至 2026-06-27
- 核心变更：建立 SwiftUI App、SwiftData 模型、文件存储、模型下载、生成页、图库、提示词库、native backend bridge、科幻 UI、模拟器 smoke test 脚本。
- 关键文件：
  - `LocalDiffusion/App/LocalDiffusionApp.swift`
  - `LocalDiffusion/Models/AppModels.swift`
  - `LocalDiffusion/Inference/ImageGenerationBackend.swift`
  - `LocalDiffusion/Views/**`
  - `NativeBackend/StableDiffusionCpp/StableDiffusionCppBridge.mm`
  - `Scripts/check-native-backend.sh`
  - `Scripts/smoke-test-simulator.sh`
- 验证结果：历史记录显示已完成 Swift 解析、native bridge 解析、native backend preflight、iPhoneOS 构建、Simulator 构建、安装、启动和截图检查。
- 遗留事项：真实端到端推理仍需在真机或可运行模拟器环境加载真实 GGUF 模型完成一次生成。

### v0.2 / 多 Agent 迭代文档体系

- 日期：2026-06-28
- 核心变更：建立标准多 Agent 迭代工作流和项目记忆文档，明确“人工 -> Agent A -> Agent B -> Agent C -> 人工复核 -> 下一轮”的长期协作方式。
- 关键文件：
  - `AGENTS.md`
  - `update_log.md`
  - `md/prompt/README.md`
  - `md/test/test.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `README.md`
- 验证结果：文档-only 修改，已运行 `git diff --check`，通过。
- 遗留事项：后续每个实现版本都应由 Agent A 创建具体实现提示词，并由 Agent B/C 完成实现与验收闭环。

### v0.3 / Agent C 验收后版本提交工作流

- 日期：2026-06-29
- 核心变更：明确 Agent C 最终验收通过后必须按版本号创建 git 提交；验收不通过时必须列出问题并退回 Agent B 修复，不得提交失败版本。
- 关键文件：
  - `AGENTS.md`
  - `update_log.md`
  - `README.md`
  - `md/prompt/README.md`
  - `md/prompt/v0（项目治理）/v0.3（AgentC通过后版本提交）.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
- 验证结果：文档-only 修改，已运行 `git diff --check`，通过。
- 遗留事项：后续 Agent C 若因权限或环境无法执行 git 提交，必须说明阻塞原因和待人工执行命令。

### v0.4 / 云端验证与 main 直推协作流程

- 日期：2026-07-03
- 核心变更：将默认协作制度从本地提交验收升级为本地轻量检查、`main` 版本提交、`git push origin main`、GitHub Actions 云端重验证、未加密 CI 结果包上传、Agent C 下载复判的闭环。
- 关键文件：
  - `AGENTS.md`
  - `README.md`
  - `md/prompt/README.md`
  - `md/prompt/v0（项目治理）/v0.4（云端验证main直推流程）.md`
  - `md/test/test.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `.github/workflows/ci-results.yml`
- 验证结果：本轮是治理流程和 CI 骨架改造，需运行 `git diff --check`、`plutil -lint LocalDiffusion.xcodeproj/project.pbxproj`、workflow YAML 解析；真实云端 run 需在配置 `origin` 后执行。
- 遗留事项：首次云端 run 暴露出 `LocalDiffusionNative.xcframework` 被 `.gitignore` 排除，远端 checkout 缺少 native binary，需用 Release asset 或等价机制恢复。

### v0.5 / CI 恢复 native XCFramework 资产

- 日期：2026-07-03
- 核心变更：让 `ci-results` workflow 在云端构建前从 GitHub Release `native-backend-current` 下载 `LocalDiffusionNative.xcframework.zip`，解压到 `LocalDiffusion/Frameworks`，再执行 native preflight 和 Xcode build。
- 关键文件：
  - `.github/workflows/ci-results.yml`
  - `md/test/test.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `README.md`
  - `update_log.md`
  - `md/prompt/v0（项目治理）/v0.5（CI恢复Native资产）.md`
- 验证结果：需要重新运行本地轻量检查、上传 Release asset、push `main` 并下载新 CI 结果包核对。
- 遗留事项：Release asset 必须在 native bridge ABI 或 stable-diffusion.cpp 包装变化后刷新；若 asset 缺失或过旧，CI 会在结果包中暴露 native preflight 或 build 失败。

### v0.5 / 引入 Agent X 循环迭代文档基线

- 日期：2026-07-04
- 核心变更：
  - 新增 Agent X 召唤、职责、循环判断和停止条件。
  - 将现有 Agent A/B/C 云端验证流程扩展为可被 Agent X 多轮调度。
  - 更新 flow、flowchart、test、prompt README 和 README 中的协作说明。
  - 明确本轮只做文档准备，不启动真实自动循环。
- 关键文件：
  - `AGENTS.md`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/test/test.md`
  - `md/prompt/README.md`
  - `md/prompt/v0（协作自动化）/v0.5（引入AgentX循环迭代）.md`
  - `update_log.md`
- 验证结果：`git diff --check` 通过。
- 遗留事项：
  - 后续人工可用 `agentx:` 提供总目标 X，启动 Agent X 主控循环。
  - Agent X 真正执行循环时，仍必须经过 Agent A 提示词、Agent B 实现 push、Agent C 云端 artifact 验收。

### v0.6 / CI 资产完整性校验

- 日期：2026-07-04
- 核心变更：
  - 新增 `NativeBackend/StableDiffusionCpp/native-backend-asset.json`，记录 native Release asset 的 tag、文件名、SHA-256、大小和刷新条件。
  - CI 下载 `LocalDiffusionNative.xcframework.zip` 后先校验 SHA-256，匹配后才解压并运行 native preflight 与 `xcodebuild`。
  - 结果包新增 `native-backend-asset.log`，manifest 记录期望摘要、实际摘要和校验结果。
  - 同步 README、测试规范和核心流程，明确 Release asset 替换后必须刷新元数据。
- 关键文件：
  - `.github/workflows/ci-results.yml`
  - `NativeBackend/StableDiffusionCpp/native-backend-asset.json`
  - `NativeBackend/StableDiffusionCpp/README.md`
  - `md/test/test.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `README.md`
  - `md/prompt/v0（项目治理）/v0.6（CI资产完整性校验）.md`
  - `update_log.md`
- 验证结果：需要运行 `git diff --check`、`plutil`、workflow YAML 解析和 `native-backend-asset.json` JSON 解析；push `main` 后由 Agent C 下载最新 CI 结果包核对。
- 遗留事项：Release asset 被替换、native bridge ABI 改变或 stable-diffusion.cpp 包装刷新时，必须同步更新 `native-backend-asset.json` 的 SHA-256。

### v1.0 / iPad 宽屏导航布局基线

- 日期：2026-07-04
- 核心变更：
  - Root 在 iPad regular size class 下继续持有唯一顶层 `NavigationSplitView`。
  - Gallery 新增 standalone 与 embedded wide 两种布局模式。
  - iPhone/compact Gallery 保留原有内部筛选 split；iPad Root detail 中改为单层 `NavigationStack`、左侧 filter rail、右侧图片网格和详情导航，避免 split 嵌套。
  - 保留 Gallery filter、sort、refresh、folder 管理、图片详情、reuse、regenerate、delete、share 和 Generate 跳转到最新图片详情的行为。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `LocalDiffusion/Views/Gallery/GalleryView.swift`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `README.md`
  - `md/prompt/v1（体验优化）/v1.0（iPad宽屏导航布局基线）.md`
  - `update_log.md`
- 验证结果：本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse 均通过；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮不启用 Mac Catalyst、不实现付费功能；后续可在此布局基线上继续做 mac/Catalyst 可行性评估和付费功能入口设计。

### v1.1 / Generate 宽屏创作台

- 日期：2026-07-04
- 核心变更：
  - Generate 页根据 horizontal size class 选择 compact 单列表单或 iPad regular 双栏创作台。
  - iPad 左栏集中模型选择、positive/negative prompt 和参数；右栏集中本地渲染状态、生成门禁、运行/取消和结果预览。
  - 保留 Save Template、默认模型选择、Open Models、Edit Prompt、Generate/Cancel、View in Gallery 和 alert 行为。
  - 不修改 Root 导航、SwiftData、文件存储、native backend 或 Xcode 平台设置。
- 关键文件：
  - `LocalDiffusion/Views/Generation/GenerationView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.1（Generate宽屏创作台）.md`
  - `update_log.md`
- 验证结果：本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse 均通过；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍不启用 Mac Catalyst、不实现付费功能；后续可继续做 mac/Catalyst 可行性和付费功能信息架构。

### v1.2 / Plan 付费能力基线

- 日期：2026-07-04
- 核心变更：
  - Root 导航新增 Plan 入口，iPhone TabView 与 iPad sidebar 均可进入。
  - Plan 页面展示当前 Local plan、StoreKit 产品未配置状态和未来付费能力候选。
  - 页面不提供购买、恢复、收据校验、订阅或 entitlement UI，不限制现有本地功能。
  - 不修改 SwiftData、文件存储、native backend、Xcode 平台设置或 StoreKit 依赖。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.2（Plan付费能力基线）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：真实付费功能仍需人工提供产品 ID、entitlement 规则、StoreKit 接入策略和 App Store Connect 配置。

### v1.3 / Mac 平台可行性基线

- 日期：2026-07-04
- 核心变更：
  - Plan 页面新增平台状态，明确 iPhone/iPad 当前可用，Mac Catalyst 当前未启用。
  - 文档记录 Mac 支持前置条件：Xcode 平台设置、native backend Mac/Catalyst slice、签名/分发配置和专门 UI 验证。
  - 不修改 `SUPPORTED_PLATFORMS`、`SUPPORTS_MACCATALYST`、native XCFramework、StoreKit、SwiftData 或 native bridge。
  - 避免把 iPad regular 布局或当前 iOS target 误称为 Mac 版本。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.3（Mac平台可行性基线）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：真正启用 Mac Catalyst 前必须先准备 native backend Mac/Catalyst slice，并明确签名、分发、UI smoke 和结果包验证策略。

### v1.4 / Plan 能力矩阵

- 日期：2026-07-04
- 核心变更：
  - Plan 页面新增能力矩阵，区分当前 Local plan 已可用能力、未来付费候选和 StoreKit 配置门槛。
  - 矩阵使用 Available、Planned、Requires configuration 状态，避免只靠颜色表达状态。
  - 移除重复的未来能力散列列表，让 Plan 付费信息架构更集中。
  - 不新增 StoreKit、价格、product ID、entitlement、SwiftData schema、native backend 或 Xcode project 改动。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.4（Plan能力矩阵）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：能力矩阵仍是信息架构；真实付费功能仍需 StoreKit 产品、entitlement 规则、App Store Connect 和购买恢复流程。

### v1.5 / Mac 就绪清单

- 日期：2026-07-04
- 核心变更：
  - Plan 页面新增 Mac readiness checklist，将 Mac 支持拆成 Xcode target 平台、native backend Mac/Catalyst slice、窗口/sidebar QA、分发和签名决策四类准备项。
  - 清单使用文字、图标和状态标签表达 Requires configuration、Requires native build、Planned、Requires decision，避免只靠颜色传达状态。
  - 继续明确当前 iPhone/iPad 可用，Mac Catalyst 未启用，不能把当前 iOS/iPadOS target 或 iPad regular 布局误称为 Mac 版本。
  - 不修改 Xcode project、native XCFramework、StoreKit、SwiftData、文件存储、native bridge 或 CI workflow。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.5（Mac就绪清单）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：真正启用 Mac Catalyst 前仍需 native backend Mac/Catalyst slice、平台设置、签名/分发决策和 Mac UI smoke 验证。

### v1.6 / Plan 宽屏布局

- 日期：2026-07-04
- 核心变更：
  - Plan 页面根据 horizontal size class 选择 compact 单列 Form 或 iPad regular 双栏阅读布局。
  - iPad regular 左栏集中 Local Plan、Current Build 和 Platform Status；右栏集中 Mac Readiness、Capability Matrix 和 Availability。
  - 宽屏布局使用 `ScrollView` 与 `ViewThatFits`，在空间不足时回退为单列堆叠，减少文字挤压风险。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData、文件存储或其他业务页面。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.6（Plan宽屏布局）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮只优化展示密度；真实付费、Mac Catalyst 和截图/Dynamic Type 目检仍需后续专门轮次。

### v1.7 / 付费权益规则基线

- 日期：2026-07-04
- 核心变更：
  - Plan 页面新增 Entitlement Rules 区，明确当前 Local plan 的 Generate、Models、Gallery、Prompts 保持可用。
  - 将 batch queue、curated prompt packs、workflow export 标记为未来付费候选，仍需产品决策且当前不售卖。
  - 明确 StoreKit purchase gate 需要 product IDs、entitlement mapping、restore/receipt flow 和 App Store Connect 配置。
  - 明确当前不保存购买状态、不授予 entitlement、不请求 App Store 产品。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData、文件存储或业务门禁。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.7（付费权益规则基线）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍是 UI/文档基线；真实 StoreKit 接入、产品 ID、购买恢复、receipt 校验、entitlement 持久化和付费门禁仍需后续人工决策与专门轮次。

### v1.8 / Plan 状态行可读性

- 日期：2026-07-04
- 核心变更：
  - 为 Plan 增加共享 `PlanStatusRow`、`PlanStatusSummaryRow` 与 `PlanStatusBadge`，统一 Current Build、Platform Status、Mac Readiness、Capability Matrix 和 Entitlement Rules 的状态展示。
  - 状态徽章使用文字、SF Symbol、颜色和描边共同表达状态，避免只靠颜色或尾部压缩标签。
  - 移除这些状态行里为尾部列挤压使用的 `lineLimit(2)` 和 `minimumScaleFactor(0.85)`，让 Dynamic Type 下文本自然换行。
  - iPad regular 在 accessibility Dynamic Type 下回退单列，普通双栏增加最小列宽；Plan overview 在 accessibility Dynamic Type 下使用纵向图标和文案布局。
  - 保持 compact Form 和 iPad regular 双栏内容顺序、事实语义和警示文案不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData、文件存储或业务门禁。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.8（Plan状态行可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.9 / Generate 动态字体宽屏回退

- 日期：2026-07-04
- 核心变更：
  - Generate 页面读取 Dynamic Type size，iPad regular 仅在非 accessibility 字号下使用双栏创作台。
  - accessibility Dynamic Type 下 Generate 回退为单列内容顺序：console、model、prompts、parameters、run、result。
  - 控制台 header、backend/model 状态 pill 和 steps/canvas metrics 在 accessibility Dynamic Type 下改为纵向或单列排列，减少横向挤压。
  - 保持 Save Template、Open Models、Edit Prompt、Generate/Cancel、View in Gallery、alert、generation gate 和生成调用行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData、文件存储、CI workflow 或其他业务页面。
- 关键文件：
  - `LocalDiffusion/Views/Generation/GenerationView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.9（Generate动态字体宽屏回退）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.10 / Models 控件可读性

- 日期：2026-07-04
- 核心变更：
  - Models 页的未跟踪文件导入/删除按钮和模型行 Details、Delete、Pause、Cancel、Resume、Download 按钮改为带文本的 `Label`，视觉上继续保持 icon-only Sci-Fi 控件。
  - 行内模型控制按钮补足 44pt 最小命中区，改善触控和辅助输入目标。
  - Storage summary、未跟踪文件行和模型行读取 Dynamic Type size，在 accessibility 字号下将状态、大小文本和控制按钮纵向堆叠，减少横向挤压。
  - 保持下载、暂停、恢复、取消、删除、导入、详情、确认弹窗和 SwiftData 保存行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或其他业务页面。
- 关键文件：
  - `LocalDiffusion/Views/Models/ModelLibraryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.10（Models控件可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.11 / Prompts 控件可读性

- 日期：2026-07-04
- 核心变更：
  - Prompt Library 的分类操作菜单、模板编辑和模板加载控件改为带文本的 `Label`，视觉上继续保持 icon-only Sci-Fi 控件。
  - 分类菜单触发器、模板编辑按钮和模板加载按钮补足 44pt 最小命中区，改善触控和辅助输入目标。
  - 分类 header 和模板行读取 Dynamic Type size，在 accessibility 字号下将标题、操作按钮和参数 pill 纵向堆叠，减少横向挤压。
  - 保持模板加载、编辑、添加、删除、分类重命名、分类清空、搜索和保存行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或其他业务页面。
- 关键文件：
  - `LocalDiffusion/Views/Prompts/PromptLibraryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.11（Prompts控件可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.12 / Gallery 图块可读性

- 日期：2026-07-04
- 核心变更：
  - Gallery 网格读取 Dynamic Type size，在 accessibility 字号下使用更宽的自适应最小列宽，减少图块横向挤压。
  - ImageTile 的输出尺寸徽章和底部元数据不再使用过小的 `caption2`，prompt 在 accessibility 字号下允许最多 3 行。
  - 日期和模型名在 accessibility Dynamic Type 下改为纵向排列，模型名可换行。
  - 图块提供由 prompt、模型、日期和输出尺寸组成的辅助功能摘要，改善 VoiceOver 读法。
  - 保持 Gallery 过滤、排序、详情、Reuse、Regenerate、Delete、Share、folder/tag 编辑和跳转行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或其他业务页面。
- 关键文件：
  - `LocalDiffusion/Views/Gallery/GalleryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.12（Gallery图块可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.13 / 共享参数控件可读性

- 日期：2026-07-04
- 核心变更：
  - ParameterEditor 为 Steps、CFG、Seed、Size、Width、Height、Sampler 补足明确 accessibility label/value。
  - Seed 随机按钮改为带文本的 `Label`，普通字号保持 icon-only 视觉，并补足 44pt 命中区。
  - CFG、Seed 和 Size 行读取 Dynamic Type size，在 accessibility 字号下使用纵向布局，减少横向挤压。
  - SciFiStatusPill 移除 `minimumScaleFactor`，在 accessibility Dynamic Type 下允许长状态文字换行。
  - SciFiMetric 在 accessibility Dynamic Type 下改为纵向图标/文本布局，value 不再只能单行截断，并提供组合后的辅助功能语义。
  - 保持 Reset defaults、steps、CFG slider、seed field/randomize、size presets、width/height steppers、sampler picker 行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/Shared/ParameterEditor.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.13（共享参数控件可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.14 / Prompt 模板编辑体验

- 日期：2026-07-04
- 核心变更：
  - PromptTemplateEditor 的 positive prompt 和 negative prompt 从裸 `TextEditor` 改为带可见标题、placeholder、字符计数、panelSoft 背景和 accent 描边的编辑区。
  - 模板 prompt 编辑区读取 Dynamic Type size，在 accessibility 字号下提高最小编辑高度，减少输入区域过矮的问题。
  - 两个 prompt 编辑区补足明确 accessibility label、value 和 hint，帮助 VoiceOver 区分 positive/negative prompt 用途。
  - 保持模板名称、分类、Save disabled、Save/Cancel、模板新增/编辑/从 Generate 保存和共享 ParameterEditor 行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/Prompts/PromptLibraryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.14（Prompt模板编辑体验）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.15 / Generate 提示词编辑器可读性

- 日期：2026-07-04
- 核心变更：
  - Generate prompt editor 的 header 在 accessibility Dynamic Type 下改为纵向可读布局，避免标题、字符计数和清除按钮强制横向挤压。
  - 字符计数从裸数字和过小 `caption2` 改为更清晰的 `N chars` 文案与 `.caption.monospacedDigit()`。
  - 清除 prompt 按钮改为带文本的 `Label`，普通字号保持 icon-only 视觉，并补足 44pt 命中区与明确辅助功能 hint。
  - Prompt placeholder 避免拦截触摸和重复 VoiceOver 朗读，TextEditor 补足 label、value 和 positive/negative prompt 用途 hint。
  - accessibility Dynamic Type 下提高 prompt 编辑区最小高度，保持普通字号的现有高度和暗色 Sci-Fi panelSoft 视觉。
  - 保持 prompt/negativePrompt binding、focusPrompt、Save Template、generation gate、Generate/Cancel 和 View in Gallery 行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/Generation/GenerationView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.15（Generate提示词编辑器可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.16 / Gallery 详情可读性

- 日期：2026-07-04
- 核心变更：
  - Gallery 图片详情页的参数区从系统 `LabeledContent` 改为项目风格的可读参数行。
  - Prompt 和非空 Negative 参数使用纵向长文本布局，accessibility Dynamic Type 下所有参数行改为纵向 label/value，减少横向挤压。
  - 参数行补足明确 accessibility label/value，长 value 可自然换行，不使用缩放压缩。
  - Reuse Parameters、Reuse and Generate、Share PNG 和 Save Tags 操作补足 44pt 行高与明确辅助功能 hint。
  - Tags 输入在 accessibility Dynamic Type 下允许更多可见行，保持普通字号紧凑。
  - 保持 Reuse、Regenerate、Delete、Share、Folder picker、Tags 保存、图片文件删除和 SwiftData 保存行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/Gallery/GalleryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.16（Gallery详情可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.17 / Gallery 筛选栏可读性

- 日期：2026-07-04
- 核心变更：
  - Gallery 左侧筛选栏的 All Images、folder 和 tag 行从裸 `Label` 改为项目风格的可读筛选行。
  - 筛选行显示对应图片数量，保留真实文本 label 和 SF Symbol，并保持至少 44pt 行高。
  - accessibility Dynamic Type 下 folder/tag 名称可自然换行，iPad embedded wide filter rail 小幅加宽，减少横向挤压。
  - 筛选行补足明确 accessibility label/value/hint，区分 all、folder 和 tag filter。
  - 当前筛选 toolbar label 在大字号下允许换行，并提供 selected filter 的辅助功能 label/value。
  - Refresh Gallery、Sort 和 New Folder toolbar 控件补足辅助功能 hint。
  - 保持 filter selection、sort selection、folder rename/delete、tag filter、refresh reconcile、新建 folder、图片网格和详情导航行为不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/Gallery/GalleryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.17（Gallery筛选栏可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator screenshot/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.18 / Plan 可访问性语义

- 日期：2026-07-05
- 核心变更：
  - Plan overview 合并为明确辅助功能元素，朗读 Local Plan、StoreKit 未配置、未保存 purchase state/entitlement、未请求 App Store product。
  - `PlanStatusSummaryRow` 显式提供 accessibility label/value，状态值由父 row 负责表达。
  - `PlanStatusRow` 显式提供包含 title/detail 的 accessibility label，并把状态写入 accessibility value。
  - `PlanStatusBadge` 保持视觉样式不变，但在父 row 已提供状态 value 时不再重复暴露给辅助技术。
  - 保持 Current Build、Platform Status、Mac Readiness、Capability Matrix、Entitlement Rules 和 Availability 事实内容不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成参数语义。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.18（Plan可访问性语义）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator VoiceOver 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.19 / Plan 可用性说明可读性

- 日期：2026-07-05
- 核心变更：
  - Plan Availability 区从两条普通 `Label` 升级为项目统一的可读状态行。
  - Core local tools 行明确 Generate、Models、Gallery 和 Prompts 在 Local plan 中保持可用，并显示 Available 状态。
  - Purchase UI 行明确购买入口仍需 StoreKit products 和 entitlement mapping，并显示 Requires configuration 状态。
  - Availability 行复用现有 `PlanStatusRow` / `PlanStatusBadge` 视觉和辅助功能语义，状态由父 row 提供 accessibility value，避免重复朗读。
  - 保持 compact Form、iPad regular 双栏布局、当前付费事实和 Mac readiness 事实不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或业务门禁。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.19（Plan可用性说明可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator VoiceOver 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.20 / Root 侧栏可访问性语义

- 日期：2026-07-05
- 核心变更：
  - iPad regular Root sidebar 从裸 `Label` 提取为私有 `SidebarSectionRow`，保留原有 title、SF Symbol、`.tag(section)` 和 `.sciFiListRow()`。
  - 每个 sidebar row 提供 44pt 最小高度，减少触控和 Dynamic Type 可读性风险。
  - 每个 sidebar row 提供明确 accessibility label、Selected / Not selected value 和 workspace hint。
  - 保持 `NavigationSplitView`、`List(selection:)`、`sidebarSelectionBinding`、`sectionContent`、compact `TabView` 和 Gallery embedded wide 逻辑不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或业务门禁。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.20（Root侧栏可访问性语义）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator sidebar/VoiceOver 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.21 / Plan 说明行可读性

- 日期：2026-07-05
- 核心变更：
  - Plan 的 StoreKit 未启用说明和 Mac 支持前置条件说明从裸 `Label` 提取为私有 `PlanNoteRow`。
  - 两条说明保留原有事实，明确当前 build 未启用 purchase/restore/receipt/subscription/entitlement，Mac 支持仍需要 Xcode 平台、native Mac/Catalyst slice、签名决策和专门 UI 验证。
  - note row 使用真实 `Label`、44pt 最小高度、可换行文本和显式 accessibility label/value/hint，提升 Dynamic Type 与 VoiceOver 可读性。
  - 保持 compact Form、iPad regular 双栏布局、当前付费事实、Mac readiness 事实、Root 导航和业务门禁不变。
  - 不修改 StoreKit、Mac Catalyst、Xcode project、native backend、SwiftData schema、文件存储、CI workflow 或生成流程。
- 关键文件：
  - `LocalDiffusion/Views/RootContentView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.21（Plan说明行可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator VoiceOver/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

### v1.22 / Models 消息行可读性

- 日期：2026-07-05
- 核心变更：
  - Models 模型行的 `progress.message` 从小号裸 `Label` 提取为私有 `ModelMessageRow`。
  - message 文本来源、下载状态、删除/导入/reconcile 行为保持不变。
  - message row 使用真实 `Label`、`SciFiTheme.amber`、44pt 最小高度、可换行文本和显式 accessibility label/value/hint，提升下载/存储状态消息的 Dynamic Type 与 VoiceOver 可读性。
  - 不修改 `HuggingFaceDownloadManager`、`ModelDownloadProgress`、`LocalModel`、SwiftData schema、文件存储、native backend、CI workflow、导航或业务行为。
- 关键文件：
  - `LocalDiffusion/Views/Models/ModelLibraryView.swift`
  - `README.md`
  - `md/flow/flow.md`
  - `md/flow/flowchart.md`
  - `md/prompt/v1（体验优化）/v1.22（Models消息行可读性）.md`
  - `update_log.md`
- 验证结果：需要运行本地 `git diff --check`、`plutil`、workflow YAML 解析、普通 Swift parse、native bridge Swift parse、沙箱外 iPhoneOS build；GitHub Actions 结果包由 Agent C 下载核对。
- 遗留事项：本轮仍未做 simulator VoiceOver/Dynamic Type 目检；真实 StoreKit、Mac Catalyst 和真机 GGUF 生成仍需后续专门轮次。

## 历史维护记录

- 2026-06-28：将旧的单文件 `agent.md` 思路迁移为标准 `AGENTS.md` + `update_log.md` + `md/` 目录体系；`agent.md` 不再作为入口文件。
