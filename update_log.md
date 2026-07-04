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

## 历史维护记录

- 2026-06-28：将旧的单文件 `agent.md` 思路迁移为标准 `AGENTS.md` + `update_log.md` + `md/` 目录体系；`agent.md` 不再作为入口文件。
