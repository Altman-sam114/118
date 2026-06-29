# AGENTS.md

本文是 Local Diffusion 的入口记忆、项目总览、基本规则和多 Agent 迭代工作流。

## 1. 项目一句话总览

Local Diffusion 是一个原生 iOS SwiftUI + SwiftData 应用，用于管理 GGUF 模型、调用 stable-diffusion.cpp native backend，并在本机完成图片生成、图库管理和提示词模板复用。

## 2. 必读文件顺序

每轮任务开始前按顺序读取：

1. `AGENTS.md`
2. `update_log.md`
3. `md/flow/flow.md`
4. `md/flow/flowchart.md`
5. `md/test/test.md`
6. `README.md`
7. 与本轮目标相关的源码、脚本、测试和最新 Agent A 提示词

## 3. 项目基本规则

- 以当前工作树、git 状态、构建输出、运行结果为准，不用记忆替代事实。
- 不还原用户或其他 Agent 的改动，除非人工明确要求。
- 小步修改，不做无关重构，不擅自扩大任务范围。
- SwiftUI UI 必须保持当前简洁、暗色、明显科幻风格。
- 新增功能必须保持 SwiftData、文件存储、native backend、UI 层之间的边界。
- 每次实质性修改后，必须按 `md/test/test.md` 选择并记录测试。
- 核心逻辑、测试规范、提示词版本或项目状态变化后，必须同步更新对应文档。
- Agent C 最终验收通过后，必须按版本号创建 git 提交；验收不通过时不得提交，必须退回 Agent B 修复。

## 4. 核心架构边界

- UI 层：`LocalDiffusion/Views/**`，只负责展示、输入、导航和用户反馈。
- 状态层：`GenerationViewModel`、`HuggingFaceDownloadManager` 负责流程状态和异步任务。
- 数据层：SwiftData 模型在 `AppModels.swift`，文件存储在 `AppFileStore.swift`。
- 推理边界：UI 只能依赖 `ImageGenerationBackend`，不得直接调用 C/Objective-C++ bridge。
- Native bridge：`NativeStableDiffusionBridge.h` 与 `StableDiffusionCppBridge.mm` 只服务 stable-diffusion.cpp 接入。
- 测试脚本：`Scripts/check-native-backend.sh` 和 `Scripts/smoke-test-simulator.sh` 是当前核心验证入口。

## 5. 标准迭代工作流

### 5.1 人工

人工提出目标、限制、验收标准、性能要求、UI 要求或测试要求。人工复核 Agent C 的验收结论后决定是否进入下一轮。

### 5.2 Agent A：目标分析与提示词

Agent A 默认不写代码，只设计本轮怎么做。

必须完成：

1. 阅读必读文件和相关源码。
2. 明确目标、非目标、边界、依赖、风险和验收标准。
3. 设计实现方案、模块改动、数据流变化、测试范围和禁止项。
4. 自动或按人工要求分配版本号。
5. 写入 `md/prompt/vX（阶段名）/vX.Y（任务名）.md`。

提示词必须包含：版本号、版本依据、背景、目标、非目标、架构依据、实现步骤、关键文件、测试要求、文档更新要求、验收标准、风险和禁止项。

### 5.3 Agent B：实现与测试

Agent B 按 Agent A 提示词实现。

必须完成：

1. 阅读 Agent A 提示词和必读文件。
2. 阅读相关源码和测试。
3. 小步实现，不做无关重构。
4. 按 `md/test/test.md` 选择测试层级并运行。
5. 记录实际命令、结果、未跑测试原因和风险。
6. 更新必要文档。

不得伪造测试、不得用“已验证”替代具体命令结果、不得绕过架构边界。

### 5.4 Agent C：验收、核心逻辑更新与版本提交

Agent C 验收 Agent B 的结果。

必须完成：

1. 阅读 Agent B 输出、实际 diff、测试结果和必读文件。
2. 核对是否满足 Agent A 提示词和人工目标。
3. 检查架构边界、测试覆盖、文档同步和未说明风险。
4. 更新 `md/flow/flow.md` 和 `md/flow/flowchart.md`。
5. 重要版本或历史事项同步更新 `update_log.md`。
6. 给出明确结论：通过或不通过。
7. 若不通过：列出问题、风险、缺失测试或文档差异，并退回 Agent B 修复；不得创建 git 提交。
8. 若通过：按本轮版本号暂存相关文件并创建 git 提交，提交信息简要概括该版本完成内容。
9. 输出通过/不通过、问题清单、已更新文档、git 提交哈希、版本工作概括和下一步建议。

版本提交规则：

- 提交主题使用 `vX.Y: 简要任务名`，例如 `v0.3: Agent C version commit workflow`。
- 提交正文可用 2-4 条短句概括完成内容、验证命令和遗留风险。
- 只提交本轮相关文件，不夹带无关改动。
- 若环境或权限导致无法提交，Agent C 必须说明阻塞原因、已通过的验收项和待人工执行的 git 命令。

## 6. 测试规则

- 每次实现前先读 `md/test/test.md`。
- 默认从 Probe / Fast 开始，按改动风险升级到 Smoke、Stage Regression 或 Full。
- SwiftUI/UI 变更至少要做 Swift 解析；重大 UI 改动应做模拟器 smoke test 和截图目检。
- Native backend 相关改动必须跑 `Scripts/check-native-backend.sh`，接口变化还要重建 XCFramework。
- 文档-only 修改可只跑 `git diff --check`，但最终回复要说明未跑业务测试的原因。
- Codex 沙箱可能阻止 SwiftData macro 和 CoreSimulator；必要时请求沙箱外执行。

## 7. 文档规则

- `AGENTS.md`：只写入口规则、架构边界和多 Agent 工作流，不堆历史。
- `update_log.md`：记录正式版本、重要维护事项、关键决策和遗留问题。
- `md/flow/flow.md`：记录当前真实核心逻辑，不写历史废话。
- `md/flow/flowchart.md`：用 mermaid 展示当前核心数据流、执行流和 Agent 迭代流。
- `md/test/test.md`：记录测试分层、命令、触发条件和当前基线。
- `md/prompt/`：保存每轮 Agent A 给 Agent B 的详细提示词。
- README：面向人类使用者，记录项目功能、构建、验证和重要维护入口。

## 8. 交付格式

每轮最终输出必须包含：

- 本轮改了什么。
- 关键文件。
- 实际运行的测试命令和结果。
- 未跑测试及原因。
- 已知风险。
- 下一步建议。

Agent C 额外输出：验收通过/不通过、问题清单、已更新的核心逻辑文档。

Agent C 通过时还必须输出：版本号、git 提交哈希、提交说明摘要和本版本工作概括。

## 9. 禁止项

- 禁止跳过必读文件直接开发。
- 禁止伪造测试通过。
- 禁止把 mock backend 当作生产推理验收。
- 禁止 UI 直接调用 native C bridge。
- 禁止无确认删除旧实现或用户改动。
- 禁止把历史流水账写进 `AGENTS.md`。
- 禁止新增测试规范后不更新 `md/test/test.md`。
- 禁止核心流程变化后不更新 `md/flow/flow.md` 和 `md/flow/flowchart.md`。
- 禁止 Agent C 在验收不通过时创建版本提交。
- 禁止伪造 git 提交哈希或用未提交状态冒充已提交版本。
