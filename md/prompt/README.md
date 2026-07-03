# Prompt 目录

本目录保存每轮 Agent A 写给 Agent B 的详细实现提示词。

## 命名建议

- `md/prompt/v0（项目治理）/v0.1（建立迭代文档）.md`
- `md/prompt/v0（项目治理）/v0.2（优化测试规范）.md`
- `md/prompt/v1（核心功能）/v1.0（真实模型生成验收）.md`
- `md/prompt/v1（核心功能）/v1.1（修复真实生成问题）.md`

## 版本管理规则

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；若任务需要 A/B/C 边界，先提醒用户指定角色或说明本轮按普通任务执行。
- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`
- Agent A 每次写提示词都必须写入版本号。
- 人工指定版本时，以人工指定为准。
- 人工未指定版本时，Agent A 自动判断版本，从 `v0.1` 开始。
- 同一阶段的小任务、修复、优化递增小版本，例如 `v0.1` -> `v0.2` -> `v0.3`。
- 大任务、架构阶段、核心功能阶段或重要里程碑新开大版本，例如 `v0.x` -> `v1.0`。
- 同一大版本下的提示词放在同一个目录，例如 `md/prompt/v0（项目治理）/`。
- 文件名使用 `v0.1（简要说明）.md`，说明要短，能表达本轮目标。
- Agent B 默认在 `main` 上创建同一版本号的 git commit，并 `git push origin main` 触发 GitHub Actions。
- Agent C 默认下载并核对 `origin/main` 最新 commit 对应的未加密 CI 结果包；验收不通过时退回 Agent B 在 `main` 上追加修复 commit。
- 版本提交主题使用 `vX.Y: 简要任务名`，正文简要说明完成内容、本地轻量检查、云端 run 和遗留风险。

## 云端阶段要求

Agent A 写给 Agent B 的提示词必须包含：

- 当前版本号和版本分配依据。
- 本轮是否必须在 `main` 上实现、提交并 push 到 `origin/main`。
- 本地轻量检查命令，默认至少包括 `git diff --check`；workflow 或工程文件变化还要包括 YAML/Plist 解析。
- 是否需要 Swift parse、native preflight、simulator smoke、真机真实 GGUF 生成等额外本机检查。
- GitHub Actions workflow 名称、预期结果包内容和 artifact 命名要求。
- Agent B 必须记录 commit SHA、push 目标、run id、run attempt、artifact 名称或无法云端验证的阻塞原因。
- Agent C 必须 `gh auth login` 后下载结果包到 `/private/tmp/localdiffusion-c-review-<run_id>/`，核对 manifest、JUnit/等价摘要、主日志和 failure summary。
- 云端失败时的退回方式：Agent B 在 `main` 上追加修复 commit 并重新 push，不创建 PR，不回滚式处理。

默认不引入 `smalldata_test`、`develop`、`codeb/...` 或 PR 合并流；除非人工后续明确要求，否则提示词不能把这些写成默认流程。

## 每份提示词必须包含

- 版本号。
- 版本分配依据。
- 背景。
- 目标。
- 非目标。
- 当前架构依据。
- 实现步骤。
- 关键文件。
- 测试要求。
- main push 和云端 CI 结果包要求。
- 文档更新要求。
- 验收标准。
- 风险和禁止项。
