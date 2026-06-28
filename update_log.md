# 项目版本更新记录

本文记录项目正式版本、重要维护事项、关键决策和遗留问题。这里不是流水账，只记录会影响后续开发判断的事实。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新功能版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。
- Agent C 负责在验收阶段判断是否需要追加或修正本文件。

## 当前状态

- 项目类型：原生 iOS SwiftUI + SwiftData 应用。
- 目标能力：管理 GGUF 模型，调用 stable-diffusion.cpp native backend，在本机完成图片生成、图库管理和提示词模板复用。
- 当前 UI：简洁暗色科幻风，核心共享样式集中在 `LocalDiffusion/Views/Shared/ParameterEditor.swift`。
- 当前 native 路径：`ImageGenerationBackend` 协议隔离，`USE_STABLE_DIFFUSION_CPP` 启用 stable-diffusion.cpp XCFramework。
- 当前验证入口：Swift 解析、native bridge 解析、`plutil`、`Scripts/check-native-backend.sh`、`Scripts/smoke-test-simulator.sh`、沙箱外 `xcodebuild`。
- 当前分支事实：读取时在 `main`，最新提交为 `d7c9258`，工作树包含文档体系迁移改动。

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
- 验证结果：文档-only 修改，要求至少运行 `git diff --check`。
- 遗留事项：后续每个实现版本都应由 Agent A 创建具体实现提示词，并由 Agent B/C 完成实现与验收闭环。

## 历史维护记录

- 2026-06-28：将旧的单文件 `agent.md` 思路迁移为标准 `AGENTS.md` + `update_log.md` + `md/` 目录体系；`agent.md` 不再作为入口文件。
