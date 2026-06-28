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

- `RootContentView` 管理 Generate、Models、Gallery、Prompts 四个入口。
- iPhone 使用 TabView，iPad 使用 NavigationSplitView。
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

- Generate：输入 prompt、参数、选择模型、启动/取消生成、展示结果。
- Models：下载、导入、暂停、恢复、删除、检查未追踪模型文件。
- Gallery：查看、过滤、排序、复用参数、删除图片。
- Prompts：保存、分类、编辑、加载模板。
- Shared：Sci-Fi theme、面板、按钮、空状态、底部留白。

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

## 3. 架构边界

- SwiftUI View 不能直接处理文件系统细节，必须经过 `AppFileStore` 或 manager。
- SwiftUI View 不能直接调用 stable-diffusion.cpp bridge。
- `GenerationViewModel` 可以协调生成流程，但不负责下载模型。
- `HuggingFaceDownloadManager` 可以更新模型下载状态，但不负责生成图片。
- SwiftData 只保存元数据，图片和模型大文件保存在 Application Support。
- native backend 只能通过 `ImageGenerationBackend` 暴露给上层。

## 4. 测试映射

- Swift 源码变更：Probe / Fast。
- UI/导航/启动变更：Smoke。
- native bridge / project / XCFramework 变更：Stage Regression。
- release 或真实生成链路变更：Full。
- 文档-only：`git diff --check`，并说明未跑业务测试。

## 5. 用户入口

- Generate：主要生成入口。
- Models：模型下载、导入、删除、状态恢复入口。
- Gallery：生成结果查看、过滤、复用入口。
- Prompts：提示词模板维护入口。
- StartupFailureView：SwiftData store 无法打开时的错误入口。

## 6. 已确认铁律

- native backend 未链接时必须给明确错误，不允许静默失败。
- mock backend 不能作为真实推理验收。
- 模型文件不存在时必须把模型状态标记为 failed 或提示用户恢复。
- 图片文件保存失败时不能留下 SwiftData 孤立记录。
- 每次核心流程变化必须同步更新 `flow.md` 与 `flowchart.md`。

## 7. 未来扩展点

- 真实 GGUF 端到端验收脚本。
- SwiftData migration 和 store 修复工具。
- 更细的 native 错误分类。
- 图片生成队列和历史任务恢复。
- 更严格的截图 smoke test：像素检查或 UI 文本检查。
- ModelLibraryView 拆分为更小的 feature files。

## 8. 不允许破坏的行为

- Generate 无模型时必须能引导用户去 Models。
- Models 空状态必须能下载或导入。
- Prompt Library 模板能加载回 Generate。
- Gallery 复用参数不能丢失 prompt、seed、尺寸和 sampler。
- 取消生成不能保存半成品。
- `Scripts/check-native-backend.sh` 必须能发现 native linkage/ABI 包装问题。
