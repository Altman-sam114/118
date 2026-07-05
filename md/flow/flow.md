# 项目核心流程文档

本文只记录当前真实核心链路，不写历史流水账。

## 0. 一句话总览

当前项目主链路是：

```text
用户输入 / 模型文件
  -> SwiftUI 页面收集操作
  -> SwiftData 元数据 + Application Support 文件存储
  -> GenerationViewModel 组装 ImageGenerationRequest
  -> ImageGenerationBackend 选择 native/mock/unavailable 后端
  -> stable-diffusion.cpp bridge 生成 PNG
  -> 保存图片文件与 SwiftData 记录
  -> Gallery / Prompt Library / Generate 页面复用结果
```

## 1. 核心模块

### 1.1 App 启动层

职责：

- 创建 `AppFileStore.shared`。
- 创建 SwiftData `ModelContainer`。
- 创建 `HuggingFaceDownloadManager`。
- SwiftData 创建失败时显示 `StartupFailureView`，不直接崩溃。

输入：

- 本地 SwiftData store。
- Application Support 文件目录。

输出：

- `RootContentView`。
- `downloadManager` 环境对象。

禁止：

- 在启动层直接执行推理。
- SwiftData 失败时静默进入半可用状态。

### 1.2 导航与全局状态层

职责：

- `RootContentView` 管理 Generate、Models、Gallery、Prompts、Plan 五个入口。
- iPhone 使用 TabView，iPad 使用 NavigationSplitView。
- iPad sidebar row 提供明确 selected/not-selected 辅助功能值、workspace hint 和 44pt 最小触控高度。
- iPad regular 由 Root 持有唯一顶层 split；Gallery 在 Root detail 中使用嵌入式宽屏布局，避免 split 嵌套。
- 创建并注入 `GenerationViewModel`。
- 连接生成结果到 Gallery 跳转。

输入：

- 用户导航操作。
- `GenerationViewModel.latestGeneratedImageID`。

输出：

- 当前选中页面。
- 跨页跳转。

禁止：

- 页面直接绕过 Root 修改全局导航状态。

### 1.3 模型与文件存储层

职责：

- `AppFileStore` 管理 GGUF 模型文件和生成图片文件。
- `HuggingFaceDownloadManager` 管理 Hugging Face 下载、暂停、恢复、取消、恢复未完成下载。
- `LocalModel` 保存模型元数据、下载状态、native load mode 和辅助模型文件名。

输入：

- Hugging Face 文件 URL。
- 本地 GGUF 文件。
- 用户下载/导入/删除操作。

输出：

- Application Support 中的模型文件。
- SwiftData 中的模型元数据。
- 下载进度和错误状态。

禁止：

- 只更新 SwiftData 而不处理对应文件。
- 删除文件不经确认或不处理元数据一致性。

### 1.4 生成状态层

职责：

- `GenerationViewModel` 维护 prompt、参数、选中模型、生成进度、取消状态、最新结果。
- 生成前校验模型文件存在、辅助模型存在、参数归一化。
- 生成后保存 PNG 文件，插入 `GeneratedImage`，记录输出尺寸和标签。

输入：

- `GenerationParameters`。
- `LocalModel`。
- SwiftData `ModelContext`。
- `ImageGenerationBackend`。

输出：

- 生成图片数据。
- Application Support 中的 PNG。
- SwiftData `GeneratedImage` 记录。

禁止：

- 生成完成前写入不完整 SwiftData 记录。
- 文件保存失败后保留孤立 SwiftData 记录。
- 取消生成时继续保存结果。

### 1.5 推理后端层

职责：

- `ImageGenerationBackend` 定义统一生成接口。
- `InferenceBackendFactory` 根据编译 flag 选择后端。
- `UnavailableInferenceBackend` 提供未链接 native backend 的明确错误。
- `MockLocalInferenceBackend` 仅用于 UI 开发占位。
- `StableDiffusionCPPInferenceBackend` 调用 C bridge。

输入：

- `ImageGenerationRequest`。
- 模型文件 URL。
- progress callback。

输出：

- PNG Data。
- 进度阶段。
- native 错误或取消错误。

禁止：

- UI 直接调用 C bridge。
- 把 mock backend 作为真实推理验收。

### 1.6 Native bridge 层

职责：

- `NativeStableDiffusionBridge.h` 定义 C ABI。
- `StableDiffusionCppBridge.mm` 调用 stable-diffusion.cpp API。
- 支持 full model 和 standalone diffusion model 路径。
- 传递 CLIP-L、CLIP-G、T5XXL、VAE 辅助模型路径。
- 传递 progress 和 cancellation。

输入：

- `LDIImageGenerationInput`。
- progress callback。
- cancellation token。

输出：

- `LDIImageResult`，包含 PNG bytes 或错误信息。

禁止：

- Swift 结构体与 C ABI 不同步。
- 修改 bridge ABI 后不重建 XCFramework。

### 1.7 UI 展示层

职责：

- Generate：输入 prompt、参数、选择模型、启动/取消生成、展示结果；prompt 编辑器 header、清除控件、参数重置作用范围、seed 文本框编辑语义、随机 seed 当前值、canvas size preset 更新 width/height 且保留自定义尺寸编辑的语义、width/height 画布像素尺寸语义、sampler 采样算法选择语义、steps 去噪步数调整语义、CFG prompt guidance strength 语义、运行门禁、进度、取消按钮、结果预览和 Gallery handoff 提供明确可访问标签/值/提示，并在 accessibility Dynamic Type 下减少横向挤压。
- Root：iPhone 使用 compact TabView；iPad 使用单层 NavigationSplitView，sidebar 行保持真实文本和 SF Symbol，提供 selected/not-selected 辅助功能值、workspace hint、44pt 最小触控高度和系统 pointer hover affordance。
- Generate 在 compact 下保持单列表单；在 iPad regular 普通 Dynamic Type 下使用双栏创作台，左侧放模型/prompt/参数，右侧放状态、运行和结果；accessibility Dynamic Type 下回退单列，控制台 header、状态 pill 和 metrics 纵向/单列排列以保持可读。
- Models：下载、导入、暂停、恢复、删除、检查未追踪模型文件；Add Model 支持 URL 解析和完成字段的键盘提交语义，Download 按钮提供 ready/missing VoiceOver 状态；行内控制按钮提供可访问文本 label、模型名上下文和 44pt 命中区，storage/model/untracked rows 在 accessibility Dynamic Type 下改为纵向堆叠以保持可读，未跟踪文件行和 Import/Delete 操作提供具体文件上下文，Storage Matrix 提供 ready/tracked/on-disk/untracked 组合 VoiceOver 摘要，Add Model 错误、模型行和详情状态消息使用可换行 message row 并提供明确辅助功能 label/value/hint。
- Gallery：查看、过滤、排序、复用参数、删除图片；筛选栏、图块、详情页参数/操作和 Organization 控件在 accessibility Dynamic Type 下使用可读布局、清晰辅助功能语义和足够触控区域，Sort menu 暴露当前排序值，筛选栏 rows 和图片图块提供系统 pointer hover affordance，Folder/Tags/Save Tags 会暴露当前值与未保存状态。
- Gallery 在 compact/standalone 下保留内部筛选 split；在 iPad Root detail 下使用左侧 filter rail + 图片网格 + detail navigation 的单层宽屏布局。
- Prompts：保存、分类、编辑、加载模板；无模板和搜索无结果状态提供组合 VoiceOver 状态、搜索上下文和下一步提示，分类菜单提供 44pt 命中区、系统 pointer hover affordance 和分类上下文 VoiceOver 语义，模板编辑和加载控件提供可访问文本 label、模板名上下文和 44pt 命中区，模板行、模板 prompt 编辑区和共享参数编辑控件在 accessibility Dynamic Type 下保持可读，并让参数重置说明会保留 positive / negative prompt、Seed 文本框说明会编辑当前参数的 seed value、随机 seed 按钮说明当前值与生成新 seed 的操作、canvas size preset 说明会同时更新 width/height 且自定义尺寸仍可编辑、Width/Height stepper 说明会调整当前参数的画布像素尺寸、sampler picker 说明会选择当前参数的采样算法、Steps stepper 说明会调整当前参数的去噪步数、CFG slider 说明会调整当前参数的 prompt guidance strength。
- Plan：展示当前 Local plan、StoreKit 未配置状态、能力矩阵、entitlement rules、availability rows、平台状态和 Mac readiness checklist；compact 使用单列 Form，iPad regular 使用双栏阅读布局，accessibility Dynamic Type 下回退单列，宽屏自定义 panel 标题提供 heading 语义且 footer note 带面板上下文；Current Build、Platform Status、Mac readiness、能力矩阵、权益规则和可用性说明使用文字、图标、颜色和描边共同表达的状态徽章，StoreKit 未启用和 Mac 支持前置条件说明使用可换行 note row，并为 VoiceOver 提供明确 label/value/hint，避免只靠颜色或尾部压缩标签表达状态；能力矩阵、权益规则和可用性说明一致明确当前本地工具保持可用，Batch queue、curated prompt packs、workflow export 这三项付费候选仍是 Planning only 且未售卖/未解锁，Purchase UI 仍需 StoreKit 与 entitlement mapping 且未持久化 entitlement，Mac app 当前 Not enabled，当前 iPhone/iPad 可用，Mac Catalyst 未启用且 Mac 前置条件仍未完成。
- Shared：Sci-Fi theme、面板、按钮、空状态、底部留白、共享参数编辑器、状态 pill 和 metric 卡片；共享 Sci-Fi 主/次按钮提供系统 pointer hover affordance，共享参数/状态控件在 accessibility Dynamic Type 下避免单行压缩并提供明确辅助功能语义，Reset Defaults 会暴露重置范围和 prompt 保留语义，Seed 文本框会暴露编辑当前生成参数 seed value 的 hint，Randomize Seed 会暴露当前 seed 和生成新随机 seed 的 hint，Canvas Size preset 会暴露 preset 对 width/height 的成对更新范围和自定义尺寸仍可编辑的 hint，Width/Height stepper 会暴露调整当前生成参数画布像素尺寸的 hint，Sampler picker 会暴露选择当前生成参数采样算法的 hint，Steps stepper 会暴露调整当前生成参数去噪步数的 hint，CFG slider 会暴露调整当前生成参数 prompt guidance strength 的 hint。

输入：

- 用户触摸、文本输入、文件选择。
- SwiftData 查询结果。
- ViewModel 状态。

输出：

- 用户可理解的状态、错误、下一步入口。

禁止：

- 回退到默认浅色 UI。
- 空状态不给下一步操作。
- disabled 状态不可辨识。

## 2. 核心流程

### 2.1 模型准备流程

```text
用户打开 Models
  -> 粘贴 Hugging Face GGUF URL 或导入本地 GGUF
  -> 创建 / 更新 LocalModel
  -> HuggingFaceDownloadManager 下载或 AppFileStore 导入文件
  -> 更新 downloadedBytes/status/lastError
  -> SwiftData 保存
  -> Generate 页可选择 ready 模型
```

### 2.2 图片生成流程

```text
用户在 Generate 输入 prompt 和参数
  -> GenerationView 计算 generationGate
  -> 用户点击 Generate
  -> GenerationViewModel 校验 LocalModel 和文件
  -> 参数 normalizedForGeneration
  -> 组装 ImageGenerationRequest
  -> backend.generateImage
  -> native/mock/unavailable backend 返回结果或错误
  -> 保存 PNG 文件
  -> 插入 GeneratedImage
  -> 更新最新图片 id
  -> Gallery 可打开结果
```

### 2.3 取消流程

```text
用户点击 Cancel
  -> GenerationViewModel 标记 isCancelling
  -> 取消 generationTask
  -> native cancellation token 被 progress callback 感知
  -> 后端抛出 CancellationError
  -> UI 进入 Cancelled 状态
  -> 不保存图片和 SwiftData 记录
```

### 2.4 图库复用流程

```text
用户打开 Gallery 图片详情
  -> 查看 GeneratedImage 参数和元数据
  -> 选择 Reuse / Regenerate
  -> GenerationViewModel.load(image:)
  -> RootContentView 切回 Generate
  -> 用户可基于旧参数再次生成
```

### 2.5 Agent 云端版本迭代流程

```text
人工提出目标
  -> Agent A 阅读上下文并写版本提示词
  -> Agent B 同步 origin/main，确认在 main 且无无关改动
  -> Agent B 按提示词实现、更新文档、跑本地轻量检查
  -> Agent B 创建版本 commit 并 push origin main
  -> GitHub Actions 在 main push 上运行云端重验证
  -> GitHub Actions 上传未加密 CI 结果包
  -> Agent C gh auth login 后下载结果包到 /private/tmp/localdiffusion-c-review-<run_id>/
  -> Agent C 核对 origin/main 最新 commit、run id、run attempt、manifest、JUnit、日志和 failure summary
  -> 若不通过：退回 Agent B 在 main 上追加修复 commit，再 push 触发新 run
  -> 若通过：确认 main 最新 run 通过并输出验收结论
  -> 人工复核云端报告和下一轮目标
```

### 2.6 Agent X 主控循环流程

```text
人工用 agentx: / x: / X: 提供总目标 X
  -> Agent X 阅读必读文件、git 状态、已有提示词和最近 Agent 结果
  -> Agent X 将总目标拆成小轮次目标
  -> Agent A 为当前轮次写版本化提示词
  -> Agent B 按提示词实现、轻量检查、版本 commit、push origin main
  -> GitHub Actions 生成未加密 CI 结果包
  -> Agent C 下载并核对最新 artifact、manifest、JUnit/摘要、日志和 failure summary
  -> Agent X 读取 Agent C 结论
  -> 若通过且总目标未完成：拆分下一轮目标并继续 Agent A
  -> 若不通过且可修复：退回 Agent B 在 main 上追加修复 commit
  -> 若需要人工权限/决策或触发停止条件：暂停等待人工
  -> 若通过且总目标完成：宣布总目标完成
```

Agent X 只负责主控调度和轮次判断，不直接替代 Agent A、Agent B 或 Agent C。Agent X 不得跳过 Agent C 的云端 artifact 验收，也不得把旧 run、旧 artifact、本地输出或文字汇报当作最新验收依据。

Agent X 必须停止或暂停的情况：

- 总目标已完成。
- 连续 3 轮遇到同一阻塞。
- 连续 2 轮没有产生有效 diff。
- CI 连续失败且原因相同。
- 需要账号、权限、密钥、付费服务或人工决策。
- 当前工作区存在无法判断归属的冲突。
- 用户要求停止或改变方向。

### 2.7 CI 结果包流程

```text
git push origin main
  -> .github/workflows/ci-results.yml
  -> 从 GitHub Release native-backend-current 下载 LocalDiffusionNative.xcframework.zip
  -> 按 NativeBackend/StableDiffusionCpp/native-backend-asset.json 校验 SHA-256
  -> 校验通过后解压 LocalDiffusionNative.xcframework
  -> git diff --check / plutil / Swift parse / native preflight / xcodebuild
  -> 写入 ci-artifact-manifest.json
  -> 写入 ci-failure-summary.md
  -> 写入 junit.xml、native asset 校验日志和主构建日志
  -> upload-artifact 未加密结果包
  -> Agent C 下载并核对
```

## 3. 架构边界

- SwiftUI View 不能直接处理文件系统细节，必须经过 `AppFileStore` 或 manager。
- SwiftUI View 不能直接调用 stable-diffusion.cpp bridge。
- `GenerationViewModel` 可以协调生成流程，但不负责下载模型。
- `HuggingFaceDownloadManager` 可以更新模型下载状态，但不负责生成图片。
- SwiftData 只保存元数据，图片和模型大文件保存在 Application Support。
- native backend 只能通过 `ImageGenerationBackend` 暴露给上层。
- CI 使用 `native-backend-asset.json` 约束 Release asset 摘要，摘要不一致时不能继续 native preflight 或 build。
- 版本提交默认由 Agent B 在 `main` 上完成并 push 到 `origin/main` 触发云端验证。
- Agent C 只能验收 `origin/main` 最新 commit 对应的 Actions run 和未加密结果包。
- Agent C 不通过时必须退回 Agent B 追加修复 commit，不能用旧 run、旧 artifact 或本地未推送状态验收。
- 若 Agent C 需要补齐核心文档，必须在 `main` 上追加文档 commit、push 并等待对应云端结果包。
- Agent X 只能调度 `Agent A -> Agent B -> Agent C` 多轮迭代，不能替代任何一环的职责或验收。
- Agent X 判断继续下一轮必须基于 Agent C 对最新 `origin/main` run 和 artifact 的明确结论。

## 4. 测试映射

- 默认：本地轻量检查 + push `origin/main` 云端重验证。
- 文档-only：本地 `git diff --check`、YAML/Plist 解析；云端 workflow 仍负责结果包。
- Agent X 循环：每一轮仍按 Agent B 本地轻量检查、GitHub Actions artifact、Agent C 下载复判执行；失败轮次不能被 Agent X 当作成功继续。
- Swift 源码变更：本地 Swift parse；云端运行 Swift parse 和 Xcode build。
- UI/导航/启动变更：人工明确本机 smoke 时运行 simulator；默认云端构建验证。
- native bridge / project / XCFramework 变更：本地或云端 `Scripts/check-native-backend.sh`，接口变化还要重建 XCFramework。
- release 或真实生成链路变更：除云端验证外，仍需要真机真实 GGUF 生成验收。

## 5. 用户入口

- Generate：主要生成入口，运行门禁、生成进度、取消状态、结果预览和 Gallery handoff 提供可访问状态语义。
- Models：模型下载、导入、删除、状态恢复入口，Add Model 表单支持键盘提交和可访问确认状态，未跟踪文件行提供文件名/大小和操作上下文，Storage Matrix、Add Model 错误、带模型名上下文的行内控制、列表状态消息和详情状态消息支持可访问 label/value/hint 与大字号可读布局。
- Gallery：生成结果查看、过滤、复用入口，筛选栏、Sort menu、图块、详情参数/操作和 Organization 控件支持大字号可读布局、VoiceOver 摘要、筛选栏和图块 pointer hover affordance、当前值和清晰操作语义。
- Prompts：提示词模板维护入口，空状态、搜索空状态、分类菜单 pointer hover 和分类上下文语义、带模板名上下文的模板行控制、模板 prompt 编辑区和共享参数编辑支持可访问 label、下一步提示与大字号可读布局。
- Plan：当前 Local plan、付费能力规划、Capability Matrix paid candidates Planning only、entitlement rules、paid candidates Planning only availability row、Mac app Not enabled 状态和平台可用性状态入口，状态行、说明 note row 和 iPad panel heading/footer 提供明确辅助功能语义。
- StartupFailureView：SwiftData store 无法打开时的错误入口。

## 6. 已确认铁律

- native backend 未链接时必须给明确错误，不允许静默失败。
- mock backend 不能作为真实推理验收。
- 模型文件不存在时必须把模型状态标记为 failed 或提示用户恢复。
- 图片文件保存失败时不能留下 SwiftData 孤立记录。
- 每次核心流程变化必须同步更新 `flow.md` 与 `flowchart.md`。
- Agent C 通过必须基于 `origin/main` 最新 commit 的云端 run 和结果包，不能只基于本地提交或文字说明。
- Agent X 不得无条件无限循环；触发停止条件时必须暂停、退回或宣布完成。

## 7. 未来扩展点

- 真实 GGUF 端到端验收脚本。
- SwiftData migration 和 store 修复工具。
- 更细的 native 错误分类。
- 图片生成队列和历史任务恢复。
- StoreKit 接入：需要 product IDs、entitlement mapping、restore/receipt flow、App Store Connect 配置和不锁定当前 Local tools 的规则确认。
- 更严格的截图 smoke test：像素检查或 UI 文本检查。
- ModelLibraryView 拆分为更小的 feature files。
- Mac Catalyst 支持：需要 Xcode 平台设置、native backend Mac/Catalyst slice、窗口/sidebar QA、签名/分发配置和专门 UI 验证；Plan 仅展示 readiness checklist，不表示 Mac 已可用。

## 8. 不允许破坏的行为

- Generate 无模型时必须能引导用户去 Models。
- Models 空状态必须能下载或导入。
- Prompt Library 模板能加载回 Generate。
- Gallery 复用参数不能丢失 prompt、seed、尺寸和 sampler。
- 取消生成不能保存半成品。
- `Scripts/check-native-backend.sh` 必须能发现 native linkage/ABI 包装问题，并纳入云端结果包日志。
- native Release asset 校验失败时必须在结果包中暴露 `native-backend-asset.log`，不能把后续 native/build 结果当作资产可用证据。
- 验收不通过的 Agent B 结果不能被 Agent C 宣布为正式通过；修复应在 `main` 上追加 commit 并重新触发云端 run。
- Agent C 不能只看文字汇报，必须核对 `ci-artifact-manifest.json`、JUnit/等价摘要、主日志和 failure summary。
- Agent X 不能绕过 Agent C artifact 验收进入下一轮，也不能用旧 artifact 或本地输出宣称总目标完成。
