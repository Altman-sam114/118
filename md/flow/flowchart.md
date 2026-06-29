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

## 4. Agent 迭代流程图

读图说明：人工先提出目标，Agent A 只负责分析和写实现提示词；Agent B 才实现和测试；Agent C 查看真实 diff、测试和文档后做通过/不通过判断。不通过就退回 Agent B 修复；通过才更新核心文档并按版本号创建 git 提交，然后交给人工复核。

```mermaid
flowchart TD
  H["人工提出目标：功能、限制、验收、测试要求"] --> A1["Agent A：阅读上下文，分析目标，设计方案"]
  A1 --> P["写入版本提示词：md/prompt/vX（阶段）/vX.Y（任务）.md"]
  P --> B1["Agent B：按提示词实现，小步修改，运行测试"]
  B1 --> R["Agent B 输出：改动、关键文件、测试结果、风险"]
  R --> C1["Agent C：查看 diff，核对测试，验收实现"]
  C1 --> D{"Agent C 验收是否通过？"}
  D -- "不通过：列问题和缺失项" --> FB["退回 Agent B 修复，不创建提交"]
  FB --> B1
  D -- "通过：确认版本完成" --> F["更新 flow.md / flowchart.md / update_log.md"]
  F --> G["按版本号创建 git commit：vX.Y: 简要任务名"]
  G --> S["输出提交哈希、版本概括、验证结果、遗留风险"]
  S --> H2["人工复核：确认提交或提出下一轮目标"]
  H2 --> H
```

## 5. 测试分层选择图

读图说明：按改动风险从小到大选择测试。文档-only 可以只做静态检查；代码、UI、native、发布前逐级加大验证范围。

```mermaid
flowchart TD
  A["本轮改动"] --> B{"只改文档？"}
  B -- "是" --> C["git diff --check"]
  B -- "否" --> D{"Swift 源码变更？"}
  D -- "是" --> E["Probe / Fast：Swift parse + native bridge parse"]
  D -- "否" --> C
  E --> F{"UI / 启动 / 导航变化？"}
  F -- "是" --> G["Smoke：simulator build + install + launch + screenshot"]
  F -- "否" --> H{"native / Xcode project / 存储主链路变化？"}
  G --> H
  H -- "是" --> I["Stage Regression：plutil + check-native-backend + iPhoneOS build"]
  H -- "否" --> J["记录测试结果"]
  I --> K{"发布前或真实生成主链路大改？"}
  K -- "是" --> L["Full：smoke + iPhoneOS build + 真机真实 GGUF 生成"]
  K -- "否" --> J
  L --> J
```
