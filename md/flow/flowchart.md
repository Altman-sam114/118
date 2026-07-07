# 项目流程图

本文用 Mermaid 展示当前核心数据流、执行流和 Agent 迭代流。每张图前都有通俗读图说明，方便人工快速理解。

## 1. 项目核心逻辑图

读图说明：从左到右看，用户先准备模型和参数，SwiftUI 把操作交给状态层，状态层读写 SwiftData 与文件系统，再通过统一后端接口进入 native/mock/unavailable 推理分支，最后把图片保存并回到 UI 展示。

```mermaid
flowchart TD
  U["用户操作：下载模型、输入 Prompt、点击生成、查看 Plan"] --> UI["SwiftUI 页面：Generate / Models / Gallery / Prompts / Plan"]
  UI --> GENUI["Generate：compact 单列表单 / iPad 双栏创作台优先且窄 regular 宽度回退单列 / Save Template readiness 语义 / 可读 prompt editor 和字段化字符计数语义 / 可读参数控件 / 参数重置语义 / Seed 输入和随机 seed 窄宽度回退语义 / 尺寸 preset 窄宽度回退和宽高像素语义 / Stepper label 窄宽度回退语义 / sampler 算法语义 / steps 去噪语义 / CFG guidance 和 header 窄宽度回退语义 / 空模型状态卡片摘要和入口语义 / 模型选择语义 / 控制台 backend/model readiness 汇总语义 / 控制台 metrics 自适应列数 / 进度阶段文本可读 / 运行状态和运行入口下一步语义 / 结果 Gallery handoff saved/unavailable 语义"]
  UI --> MODELUI["Models：下载 / 导入 / 删除 / tracked model 删除确认语义 / toolbar refresh/add menu 语义 / 空状态 no-model/no-untracked 语义 / Add Model 键盘提交和字段 label/value/hint / 未跟踪文件操作和删除确认语义 / 未跟踪 GGUF import editor 字段和 toolbar 语义 / Storage Matrix VoiceOver 摘要 / Add Model error row / 带模型名上下文的 row controls 和详情操作按钮 / Native Loading 当前值语义 / 列表和详情 message rows"]
  UI --> PROMPTUI["Prompts：模板分类 / 分类标题 heading 和当前可见模板数量语义 / Add prompt template toolbar 语义 / 搜索入口 submit 和匹配范围语义 / 分类菜单 pointer hover 和上下文语义 / 分类清除确认语义 / 空状态语义 / 模板 row positive/negative/category/参数摘要 / 模板 metric steps/sampler/size 语义 / 模板 name/category 和分类重命名 name 输入语义 / 可读编辑器和字段化字符计数语义 / Save/Cancel ready/name-required 语义 / 带模板名上下文的 controls / 共享参数重置、Seed 输入、随机 seed、尺寸 preset、Stepper label 和 CFG header 窄宽度回退语义"]
  UI --> NAV["Root 导航：iPhone TabView / iPad 单层 SplitView / neutral Plan navigation icon / Plan sidebar planning hint / 可访问 sidebar rows / pointer hover affordance"]
  NAV --> GALUI["Gallery：compact 内部筛选 split / iPad 可读 filter rail 和 pointer hover / folder actions、name field 和 delete confirmation 语义 / 空状态筛选上下文语义 / Sort 当前值语义 / 图块 label/value 拆分和 pointer hover / 详情操作和删除确认图片上下文语义 / Folder 即时保存和 draft/saved tags 语义"]
  NAV --> PLANUI["Plan：compact Form / compact footer note context 含 Availability / iPad 双栏 / neutral planning overview icon / overview purchase boundary 语义 / summary row hints / Current Build paid candidates planning-only purchase note / Platform Status Mac support planned note with no separate Mac binary/Mac signing profile/sandbox entitlement/notarization pipeline / panel heading 和 note 语义 / 可访问状态徽章和 note rows / 能力矩阵 Paid candidates Planning only、StoreKit purchases not enabled 和 row hints / entitlement rule hints 含 paid candidates 无 trial/preview entitlement、feature flag 或 unlock gate、StoreKit no App Store product request 且无 restore button/receipt validation path/entitlement mapping resolution、entitlement persistence 无 local cache/cross-launch restoration/server-side source/receipt-backed state / availability hints 含 Paid candidates Planning only、Purchase UI hidden 且无 purchase sheet/buy/unlock/restore/subscription management/product loading state、Mac app iPhone/iPad available but Mac/Catalyst not enabled and no separate Mac binary/Catalyst entitlement set/desktop distribution channel / Mac readiness footer iPhone/iPad available and Mac/Catalyst not enabled / Apple platform support iPhone/iPad target detail / native inference Mac/Catalyst slice detail / release signing decision detail with no Mac signing profile/sandbox entitlement/notarization pipeline / Needs QA / iPad layout pointer affordance 不替代 Mac/Catalyst QA validation blocker hints"]
  NAV --> VM["状态层：GenerationViewModel / HuggingFaceDownloadManager"]
  GENUI --> VM
  MODELUI --> VM
  PROMPTUI --> VM
  GALUI --> VM
  VM --> SD["SwiftData 元数据：LocalModel / GeneratedImage / GalleryFolder / PromptTemplate"]
  VM --> FS["Application Support 文件：GGUF 模型 / PNG 图片"]
  VM --> REQ["ImageGenerationRequest：参数、模型路径、辅助模型路径"]
  REQ --> IFACE["ImageGenerationBackend 协议：统一推理边界"]
  IFACE --> NATIVE["StableDiffusionCPPInferenceBackend：真实 native 推理"]
  IFACE --> MOCK["MockLocalInferenceBackend：仅 UI 开发占位"]
  IFACE --> OFF["UnavailableInferenceBackend：native 未链接时明确报错"]
  NATIVE --> BRIDGE["C / Objective-C++ bridge：stable-diffusion.cpp"]
  BRIDGE --> PNG["PNG Data + progress / error / cancel"]
  MOCK --> PNG
  OFF --> ERR["用户可见错误"]
  PNG --> SAVE["保存图片文件并插入 GeneratedImage"]
  SAVE --> GALLERY["Gallery 展示、可读筛选、可读图块和 pointer hover、folder 和图片删除确认上下文、Folder 即时保存提示和草稿/已保存状态、复用参数"]
  GALLERY --> UI
```

## 2. 图片生成执行流

读图说明：这张图只看点击 Generate 后发生什么。关键点是先校验模型和文件，再归一化参数，然后通过后端生成；成功才保存文件和 SwiftData，取消或失败不保存半成品。

```mermaid
flowchart TD
  A["点击 Generate"] --> B["检查是否正在生成"]
  B --> C{"已有 ready 模型？"}
  C -- "否：提示用户下载或选择模型" --> X1["停止"]
  C -- "是" --> D["检查主模型文件存在且非空"]
  D --> E{"辅助模型文件存在？"}
  E -- "缺失：提示 CLIP/T5/VAE 文件缺失" --> X2["停止"]
  E -- "存在或未配置" --> F["归一化参数：steps / CFG / width / height / sampler"]
  F --> G["组装 ImageGenerationRequest"]
  G --> H["调用 ImageGenerationBackend.generateImage"]
  H --> I{"生成结果"}
  I -- "成功 PNG Data" --> J["保存 PNG 到 Application Support"]
  J --> K["插入 GeneratedImage 并保存 SwiftData"]
  K --> L["更新 latestGeneratedImageID，UI 可跳 Gallery"]
  I -- "取消" --> M["状态改为 Cancelled，不保存结果"]
  I -- "失败" --> N["显示 alert，状态改为 Failed"]
```

## 3. 模型准备数据流

读图说明：模型可以来自 Hugging Face URL 或本地 GGUF 导入。SwiftData 保存的是元数据，大文件保存在 Application Support；两者必须保持一致。

```mermaid
flowchart TD
  A["用户打开 Models：空状态下载/导入入口语义 / Add Model 键盘提交和字段语义 / tracked model 删除确认语义 / 未跟踪文件操作、导入字段和删除确认语义 / Storage Matrix 摘要 / 带模型名上下文的控件 / Native Loading 当前值语义 / 大字号堆叠"] --> B{"模型来源"}
  B -- "Hugging Face GGUF URL" --> C["解析仓库、文件名、revision、URL"]
  C --> D["创建 LocalModel 元数据"]
  D --> E["HuggingFaceDownloadManager 下载"]
  E --> F["写入 Application Support 模型文件"]
  F --> G["更新 downloadedBytes / status / lastError"]
  B -- "本地 GGUF 文件" --> H["fileImporter 选择文件"]
  H --> I["AppFileStore 导入到模型目录"]
  I --> J["创建或关联 LocalModel"]
  G --> K["SwiftData 保存"]
  J --> K
  K --> L["ready 模型出现在 Generate Picker"]
```

## 4. Agent 云端迭代流程图

读图说明：人工先提出目标，Agent A 只负责分析和写实现提示词；Agent B 在 `main` 上实现、轻量检查、提交并 push；GitHub Actions 生成未加密结果包；Agent C 下载结果包并核对最新 `origin/main` 的 commit、run 和日志。不通过就退回 Agent B 在 `main` 上追加修复 commit；通过才交给人工复核。

```mermaid
flowchart TD
  H["人工提出目标：功能、限制、验收、测试要求"] --> A1["Agent A：阅读上下文，分析目标，设计方案"]
  A1 --> P["写入版本提示词：md/prompt/vX（阶段）/vX.Y（任务）.md"]
  P --> B0["Agent B：同步 origin/main，确认当前分支是 main"]
  B0 --> B1["Agent B：按提示词实现，更新必要文档"]
  B1 --> T["本地轻量检查：git diff / YAML / Plist / Swift parse"]
  T --> G1["创建版本 commit：vX.Y: 简要任务名"]
  G1 --> PUSH["git push origin main"]
  PUSH --> ACT["GitHub Actions：ci-results workflow"]
  ACT --> PKG["上传未加密 CI 结果包：manifest / JUnit / log / failure summary"]
  PKG --> C0["Agent C：gh auth login，下载 artifact 到 /private/tmp/localdiffusion-c-review-<run_id>/"]
  C0 --> C1["Agent C：核对 origin/main 最新 commit、run id、run attempt 和结果文件"]
  C1 --> D{"Agent C 云端验收是否通过？"}
  D -- "不通过：列问题和缺失项" --> FB["退回 Agent B，在 main 上追加修复 commit"]
  FB --> B1
  D -- "通过：确认 origin/main 最新 run 通过" --> S["输出提交哈希、run id、artifact 名称、验证结果、遗留风险"]
  S --> H2["人工复核：确认 main 最新版本或提出下一轮目标"]
  H2 --> H
```

## 5. Agent X 主控循环流程图

读图说明：人工用 `agentx:` 给出总目标后，Agent X 只负责拆分轮次和判断下一步。每一轮仍必须经过 Agent A 提示词、Agent B 实现并 push、GitHub Actions artifact、Agent C 下载复判。Agent X 只能基于 Agent C 的最新结果决定继续、退回、暂停或完成。

```mermaid
flowchart TD
  H["人工用 agentx: / x: / X: 提供总目标 X"] --> X0["Agent X：读取上下文、git 状态和已有 Agent 结果"]
  X0 --> X1["Agent X：拆分当前轮次目标、非目标和验收边界"]
  X1 --> NEED{"需要权限、账号、密钥、付费服务或人工决策？"}
  NEED -- "是" --> PAUSE["暂停：等待人工确认"]
  NEED -- "否" --> A["Agent A：写当前轮次版本化提示词"]
  A --> P["md/prompt/vX（阶段）/vX.Y（任务）.md"]
  P --> B["Agent B：实现、更新文档、跑本地轻量检查"]
  B --> PUSH["Agent B：版本 commit 并 git push origin main"]
  PUSH --> ACT["GitHub Actions：main push 触发 ci-results"]
  ACT --> ART["未加密 artifact：manifest / JUnit / log / failure summary"]
  ART --> C["Agent C：下载最新 artifact 并核对 commit / run / attempt"]
  C --> X2["Agent X：读取 Agent C 验收结论"]
  X2 --> D{"Agent X 判断"}
  D -- "通过且总目标未完成" --> NEXT["继续：拆分下一轮目标"]
  NEXT --> A
  D -- "不通过且可修复" --> BACK["退回：Agent B 在 main 追加修复 commit"]
  BACK --> B
  D -- "阻塞或触发停止条件" --> PAUSE
  D -- "通过且总目标完成" --> DONE["完成：输出总目标完成结论"]
```

## 6. CI 结果包数据流

读图说明：这张图只看 `main` push 后云端产物如何形成。Agent C 后续只核对此结果包，不把旧 artifact、旧输出或 Agent B 文字汇报当作验收依据。

```mermaid
flowchart TD
  A["git push origin main"] --> B["GitHub Actions：ci-results.yml"]
  B --> R["恢复 native backend：下载 Release asset"]
  R --> SHA["校验 SHA-256：native-backend-asset.json"]
  SHA --> UNZIP["校验通过后解压 XCFramework"]
  SHA --> ASSETLOG["native-backend-asset.log + manifest 摘要字段"]
  UNZIP --> C["静态检查：git diff --check / YAML / Plist"]
  B --> D["Swift parse：普通路径和 native bridge 路径"]
  UNZIP --> E["Native preflight：Scripts/check-native-backend.sh"]
  UNZIP --> F["Xcode build：Debug iPhoneOS + .xcresult"]
  C --> G["ci-artifact-manifest.json"]
  ASSETLOG --> G
  D --> G
  E --> G
  F --> G
  C --> H["junit.xml + ci-failure-summary.md + 主日志"]
  D --> H
  E --> H
  F --> H
  G --> I["未加密 artifact"]
  H --> I
  I --> J["Agent C 下载并核对 branch / commitSha / runId / runAttempt"]
```

## 7. 测试分层选择图

读图说明：默认本地只做轻量检查，完整构建和可追溯结果包交给 GitHub Actions。只有人工明确要求本机 build、simulator 或 native 重验证时，才把这些作为本机默认路径。

```mermaid
flowchart TD
  A["本轮改动"] --> B["本地轻量检查：git diff --check"]
  B --> C{"涉及 workflow / plist / Swift？"}
  C -- "workflow / plist" --> D["YAML / Plist 解析"]
  C -- "Swift 源码" --> E["Swift parse + native bridge parse"]
  C -- "否" --> F["创建版本 commit"]
  D --> F
  E --> F
  F --> G["git push origin main"]
  G --> H["GitHub Actions 云端重验证"]
  H --> I["上传未加密 CI 结果包"]
  I --> J["Agent C 下载核对"]
  J --> K{"是否通过？"}
  K -- "否" --> L["Agent B main 追加修复 commit"]
  L --> G
  K -- "是" --> M["人工复核"]
  A --> N{"人工明确要求本机完整测试？"}
  N -- "是" --> O["按风险运行 smoke / native preflight / xcodebuild / 真机 GGUF"]
  O --> F
```
