# 项目流程图

本文用 Mermaid 展示当前核心数据流、执行流和 Agent 迭代流。每张图前都有通俗读图说明，方便人工快速理解。

## 1. 项目核心逻辑图

读图说明：从左到右看，用户先准备模型和参数，SwiftUI 把操作交给状态层，状态层读写 SwiftData 与文件系统，再通过统一后端接口进入 native/mock/unavailable 推理分支，最后把图片保存并回到 UI 展示。

```mermaid
flowchart TD
  U["用户操作：下载模型、输入 Prompt、点击生成"] --> UI["SwiftUI 页面：Generate / Models / Gallery / Prompts"]
  UI --> VM["状态层：GenerationViewModel / HuggingFaceDownloadManager"]
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
  SAVE --> GALLERY["Gallery 展示、过滤、复用参数"]
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
  A["用户打开 Models"] --> B{"模型来源"}
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

## 5. CI 结果包数据流

读图说明：这张图只看 `main` push 后云端产物如何形成。Agent C 后续只核对此结果包，不把旧 artifact、旧输出或 Agent B 文字汇报当作验收依据。

```mermaid
flowchart TD
  A["git push origin main"] --> B["GitHub Actions：ci-results.yml"]
  B --> C["静态检查：git diff --check / YAML / Plist"]
  B --> D["Swift parse：普通路径和 native bridge 路径"]
  B --> E["Native preflight：Scripts/check-native-backend.sh"]
  B --> F["Xcode build：Debug iPhoneOS + .xcresult"]
  C --> G["ci-artifact-manifest.json"]
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

## 6. 测试分层选择图

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
