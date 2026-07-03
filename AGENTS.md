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
7. `md/prompt/README.md`
8. `.github/workflows/` 下已有 workflow
9. 与本轮目标相关的源码、脚本、测试和最新 Agent A 提示词

## 3. 项目基本规则

- 以当前工作树、git 状态、构建输出、运行结果为准，不用记忆替代事实。
- 不还原用户或其他 Agent 的改动，除非人工明确要求。
- 小步修改，不做无关重构，不擅自扩大任务范围。
- SwiftUI UI 必须保持当前简洁、暗色、明显科幻风格。
- 新增功能必须保持 SwiftData、文件存储、native backend、UI 层之间的边界。
- 每次实质性修改后，必须按 `md/test/test.md` 选择并记录测试。
- 核心逻辑、测试规范、提示词版本或项目状态变化后，必须同步更新对应文档。
- 默认验证策略是本地轻量检查 + `main` 直推 + GitHub Actions 云端重验证。
- Agent C 必须下载并核对未加密 CI 结果包后才能验收通过；不得只依据 Agent B 文字汇报或本地未推送状态验收。

## 4. 角色召唤和身份标识

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要 A/B/C 边界，先提醒用户指定角色或说明本轮按普通任务执行。
- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

## 5. 核心架构边界

- UI 层：`LocalDiffusion/Views/**`，只负责展示、输入、导航和用户反馈。
- 状态层：`GenerationViewModel`、`HuggingFaceDownloadManager` 负责流程状态和异步任务。
- 数据层：SwiftData 模型在 `AppModels.swift`，文件存储在 `AppFileStore.swift`。
- 推理边界：UI 只能依赖 `ImageGenerationBackend`，不得直接调用 C/Objective-C++ bridge。
- Native bridge：`NativeStableDiffusionBridge.h` 与 `StableDiffusionCppBridge.mm` 只服务 stable-diffusion.cpp 接入。
- 测试脚本：`Scripts/check-native-backend.sh` 和 `Scripts/smoke-test-simulator.sh` 是当前核心验证入口。

## 6. 标准迭代工作流

### 6.1 人工

人工提出目标、限制、验收标准、性能要求、UI 要求或测试要求。人工复核 Agent C 的验收结论后决定是否进入下一轮。

### 6.2 Agent A：目标分析与提示词

Agent A 默认不写代码，只设计本轮怎么做。

必须完成：

1. 阅读必读文件和相关源码。
2. 明确目标、非目标、边界、依赖、风险和验收标准。
3. 设计实现方案、模块改动、数据流变化、测试范围和禁止项。
4. 自动或按人工要求分配版本号。
5. 写入 `md/prompt/vX（阶段名）/vX.Y（任务名）.md`。

提示词必须包含：版本号、版本依据、背景、目标、非目标、架构依据、实现步骤、关键文件、测试要求、文档更新要求、验收标准、风险和禁止项。

### 6.3 Agent B：实现、轻量检查与 main 直推

Agent B 按 Agent A 提示词实现。

必须完成：

1. 阅读 Agent A 提示词和必读文件。
2. 阅读相关源码和测试。
3. 同步最新 `origin/main`，确认当前分支是 `main`，且工作区没有无关改动；若没有 `origin`，必须记录阻塞，不得伪造云端验证。
4. 小步实现，不做无关重构。
5. 按 `md/test/test.md` 跑本地轻量检查，默认不在本机跑完整 build 或 simulator，除非人工明确要求。
6. 更新必要文档。
7. 按版本号提交本轮相关文件，并直接 `git push origin main` 触发 GitHub Actions。
8. 记录本地命令、退出结果、push 目标、commit SHA、Actions run id 或无法触发云端验证的原因。

不得伪造测试、不得用“已验证”替代具体命令结果、不得绕过架构边界。

### 6.4 Agent C：结果包验收、核心逻辑更新与退回

Agent C 验收 Agent B 的结果。

必须完成：

1. 阅读 Agent B 输出、实际 diff、测试结果、Actions 状态和必读文件。
2. 核对是否满足 Agent A 提示词和人工目标。
3. 使用 `gh auth login` 后下载 `origin/main` 最新 commit 对应的未加密 CI 结果包到 `/private/tmp/localdiffusion-c-review-<run_id>/`。
4. 核对 `ci-artifact-manifest.json` 的 `branch`、`commitSha`、`runId`、`runAttempt` 与 `origin/main` 最新状态完全一致。
5. 检查 JUnit/等价摘要、主构建日志、failure summary、项目专属报告和未说明风险。
6. 检查架构边界、测试覆盖和文档同步。
7. 需要补齐核心逻辑文档时，在 `main` 上追加文档 commit 并重新 push，等待对应 Actions 结果包后再验收。
8. 给出明确结论：通过或不通过。
9. 若不通过：列出问题、风险、缺失测试或文档差异，并退回 Agent B 在 `main` 上追加修复 commit；不得回滚式处理或创建 PR。
10. 若通过：确认 `origin/main` 最新 run 通过，并输出版本、commit SHA、run id、artifact 名称、结果包核对结论和下一步建议。

版本提交规则：

- 提交主题使用 `vX.Y: 简要任务名`，例如 `v0.3: Agent C version commit workflow`。
- 提交正文可用 2-4 条短句概括完成内容、验证命令和遗留风险。
- 只提交本轮相关文件，不夹带无关改动。
- 任何 Agent 在 `git push origin main` 前，都必须确认当前分支是 `main`、目标远端是 `origin/main`，且提交范围只包含本轮相关文件。
- 若环境、权限或远端缺失导致无法 push 或下载 artifact，必须说明阻塞原因、已通过的验收项和待人工执行的 git/gh 命令。

## 7. main 直推与云端验证规则

- 本项目默认只使用 `main` 作为上传、提交、推送和云端验证分支。
- 暂不设计 `smalldata_test`、`develop`、`codeb/...` 或 PR 合并流；若远端已有其他分支，只记录现状，不纳入默认流程。
- Agent B 每轮开始推荐执行：

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git status --short
```

- Agent B 完成后推荐执行：

```bash
git add 相关文件
git commit -m "vX.Y: 简要说明本轮做了什么"
git push origin main
```

- Agent C 只验收 `origin/main` 最新 commit 对应的 Actions run 和 artifact，不验收旧 run、旧 artifact 或 checkout 自带旧报告。
- GitHub Actions 结果包必须未加密，并至少包含 manifest、failure summary、构建日志、JUnit 或等价摘要，以及项目专属关键报告。
- 云端失败时，Agent B 根据结果包修复后继续在 `main` 上追加 commit 并 push；默认不做回滚式处理。

## 8. 测试规则

- 每次实现前先读 `md/test/test.md`。
- 默认本地只跑轻量检查，并通过 push 到 `origin/main` 触发 GitHub Actions 重验证。
- 只有人工明确要求“本机测试”“本地 build”“本地跑探针”“本地 xcodebuild”等，才默认在本机跑完整构建、模拟器或 native 重验证。
- 默认本地轻量检查包括 `git diff --check`、YAML/Plist 解析、Swift parse 或脚本语法检查。
- SwiftUI/UI 变更至少要做 Swift 解析；重大 UI 改动应做模拟器 smoke test 和截图目检。
- Native backend 相关改动必须跑 `Scripts/check-native-backend.sh`，接口变化还要重建 XCFramework。
- 文档-only 修改可只跑 `git diff --check`，但最终回复要说明未跑业务测试的原因。
- Codex 沙箱可能阻止 SwiftData macro 和 CoreSimulator；必要时请求沙箱外执行。

## 9. 文档规则

- `AGENTS.md`：只写入口规则、架构边界和多 Agent 工作流，不堆历史。
- `update_log.md`：记录正式版本、重要维护事项、关键决策和遗留问题。
- `md/flow/flow.md`：记录当前真实核心逻辑，不写历史废话。
- `md/flow/flowchart.md`：用 mermaid 展示当前核心数据流、执行流和 Agent 迭代流。
- `md/test/test.md`：记录测试分层、命令、触发条件和当前基线。
- `md/prompt/`：保存每轮 Agent A 给 Agent B 的详细提示词。
- README：面向人类使用者，记录项目功能、构建、验证和重要维护入口。

## 10. 交付格式

每轮最终输出必须包含：

- 本轮改了什么。
- 关键文件。
- 实际运行的测试命令和结果。
- 未跑测试及原因。
- 已知风险。
- 下一步建议。
- 当前分支、commit SHA、run id、run attempt、artifact 名称。
- 是否已 push 到 `origin/main`。
- Agent C 是否下载并核对结果包。

Agent C 额外输出：验收通过/不通过、问题清单、已更新的核心逻辑文档。

Agent C 通过时还必须输出：版本号、git 提交哈希、提交说明摘要、云端 workflow 结果、结果包核对摘要和本版本工作概括。

## 11. 禁止项

- 禁止跳过必读文件直接开发。
- 禁止伪造测试通过。
- 禁止把 mock backend 当作生产推理验收。
- 禁止 UI 直接调用 native C bridge。
- 禁止无确认删除旧实现或用户改动。
- 禁止把历史流水账写进 `AGENTS.md`。
- 禁止新增测试规范后不更新 `md/test/test.md`。
- 禁止核心流程变化后不更新 `md/flow/flow.md` 和 `md/flow/flowchart.md`。
- 禁止 Agent C 在验收不通过时宣布版本通过。
- 禁止伪造 git 提交哈希或用未提交状态冒充已提交版本。
- 禁止没有权限下载 artifact 时伪装已核对；必须先 `gh auth login` 或说明权限阻塞。
- 禁止把旧 artifact、旧 output 或 checkout 自带报告冒充本轮云端结果。
- 禁止本轮默认引入 `smalldata_test`、`develop`、`codeb/...` 或 PR 流程。
- 禁止把 AITRANS 项目特例硬复制到本项目。
