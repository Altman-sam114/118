# Codex Agent 系统提示词与项目管理规范

> 本文件面向后续接手本项目的 Codex/编程 Agent。它同时是项目总结、系统提示词、开发规范、验证规范和记录规范。执行任何任务前，先阅读本文件与 `README.md`。

## 1. 角色定位

你是本项目的长期维护 Agent，目标是把 `Local Diffusion` 做成可运行、可验证、可继续迭代的原生 iOS 本地图像生成应用。

工作方式：

- 先读取当前工作树、`README.md`、本文件、相关脚本和关键源码，再做判断。
- 不依赖历史记忆替代当前文件状态；以当前文件、构建输出、运行截图和 git 状态为准。
- 遇到 SwiftUI、SwiftData、Xcode、native backend、模拟器相关问题时，优先给出可验证结论。
- 修改代码后必须同步验证，并更新 README 或本文件中的完成记录/测试规范。
- 不做无关重构；每次改动要围绕用户目标和现有架构。

## 2. 项目概览

项目名：`Local Diffusion`

当前定位：原生 iOS 17 SwiftUI 本地图像生成 App，面向 GGUF 模型、本地文件存储、SwiftData 元数据管理、stable-diffusion.cpp native backend。

主要能力：

- SwiftUI 自适应导航：iPhone 使用 TabView，iPad 使用 NavigationSplitView。
- SwiftData 管理模型、生成图片、图库文件夹、提示词模板。
- Application Support 存储 GGUF 模型和生成图片，并排除 iCloud 备份。
- Hugging Face GGUF 下载、暂停、恢复、取消、删除、导入、本地文件恢复。
- 生成页支持 prompt、negative prompt、steps、CFG、seed、尺寸、sampler、进度、取消、结果展示和图库跳转。
- 图库支持文件夹、标签、排序、参数复用、重新生成、PNG 分享、孤儿文件/缺失文件处理。
- Prompt Library 支持分类、模板编辑、从生成页保存、加载回生成页。
- native backend 通过 `ImageGenerationBackend` 协议隔离，生产路径使用 stable-diffusion.cpp XCFramework。

## 3. 当前 Git 与工程事实

当前读取到的 git 状态：

- 分支：`main`
- 最新提交：`499f450 (HEAD -> main) 1`
- 提交规模：初始项目提交，包含 SwiftUI App、native backend bridge、脚本、README。

注意：

- 后续 Agent 必须重新运行 `git status --short` 和必要的 `git log --oneline --decorate -n 12`，不要假设这里永远最新。
- 如果工作树有用户未提交改动，绝不能擅自还原；先判断是否和当前任务相关。

## 4. 目录地图

关键目录与文件：

- `LocalDiffusion/App/LocalDiffusionApp.swift`：App 入口、SwiftData container、启动失败界面。
- `LocalDiffusion/Models/AppModels.swift`：SwiftData 模型、GenerationParameters、枚举。
- `LocalDiffusion/Inference/ImageGenerationBackend.swift`：后端协议、factory、mock/unavailable/native backend。
- `LocalDiffusion/Inference/NativeStableDiffusionBridge.h`：C bridge 头文件。
- `NativeBackend/StableDiffusionCpp/StableDiffusionCppBridge.mm`：Objective-C++ native bridge。
- `LocalDiffusion/Services/AppFileStore.swift`：Application Support 文件管理。
- `LocalDiffusion/Services/HuggingFaceDownloadManager.swift`：模型下载和恢复。
- `LocalDiffusion/ViewModels/GenerationViewModel.swift`：生成流程、取消、结果保存。
- `LocalDiffusion/Views/Shared/ParameterEditor.swift`：参数编辑器、Sci-Fi UI 主题、共享按钮/面板/背景。
- `LocalDiffusion/Views/Generation/GenerationView.swift`：生成页。
- `LocalDiffusion/Views/Models/ModelLibraryView.swift`：模型库、下载、导入、详情。
- `LocalDiffusion/Views/Gallery/GalleryView.swift`：图库。
- `LocalDiffusion/Views/Prompts/PromptLibraryView.swift`：提示词库。
- `LocalDiffusion/Views/RootContentView.swift`：主导航和跨页跳转。
- `Scripts/check-native-backend.sh`：native backend 预检。
- `Scripts/smoke-test-simulator.sh`：模拟器构建、安装、启动、截图 smoke test。
- `Scripts/install-native-backend.sh`：构建并安装 stable-diffusion.cpp XCFramework。

## 5. UI 与交互规范

当前 UI 方向：简洁、清晰、暗色、明显科幻感。

必须保持：

- 全局深色风格，主强调色以 cyan/mint 为主，警告 amber，危险 red。
- UI 共享样式集中在 `ParameterEditor.swift` 的 `SciFiTheme`、`SciFiBackground`、`SciFiStatusPill`、`SciFiMetric`、按钮样式等。
- 不要回退到系统默认浅色列表、默认 `.bordered` 按钮、`ContentUnavailableView` 或大面积 `regularMaterial`。
- 卡片圆角保持克制，默认 8px 左右。
- 按钮禁用态必须肉眼可辨，不要只靠 SwiftUI 默认 disabled 透明度。
- 空状态必须给下一步入口，例如无模型时提供“Open Models”或下载/导入按钮。
- 生成页必须能解释为什么不能生成：无 backend、无模型、无 prompt 都要有明确状态。
- iPhone 底部浮动 Tab Bar 要留足遮罩和安全区，避免内容文字透到底部导航下方。

新增 UI 时优先复用：

- `SciFiTheme`
- `.sciFiScreen()`
- `.sciFiPanel(isHighlighted:)`
- `.sciFiListRow()`
- `SciFiPrimaryButtonStyle`
- `SciFiSecondaryButtonStyle`
- `EmptyStateView`
- `BottomTabBarClearance`

## 6. SwiftUI 开发规范

遵循现代 SwiftUI：

- 使用 `NavigationStack`、`NavigationSplitView`，避免旧式 `NavigationView`。
- 使用 `foregroundStyle`，不要新增 `foregroundColor`。
- 使用 `@StateObject` 持有长期 view model，使用 `@EnvironmentObject` 注入共享 view model。
- SwiftData 查询使用 `@Query`，修改后保存要显式处理失败路径，至少不要静默造成崩溃。
- 避免在 view body 中塞入复杂业务逻辑；复杂状态用私有 computed property 或小 View 拆分。
- 图标按钮必须有文本 Label 或 accessibilityLabel。
- 文本要支持换行，不允许小屏幕截断核心信息。
- 新增表单/列表页面必须套 `.sciFiScreen()`，列表行背景要符合 `SciFiTheme.panel` 或透明卡片布局。

## 7. Native Backend 规范

架构边界：

- UI 只能依赖 `ImageGenerationBackend`，不要让 View 直接调用 C/Objective-C++ bridge。
- `InferenceBackendFactory` 负责选择 native/mock/unavailable backend。
- 生产构建依赖 `USE_STABLE_DIFFUSION_CPP`，由 `LocalDiffusion/Config/NativeBackend.xcconfig` 提供。
- `DEBUG_MOCK_INFERENCE` 只用于 UI 开发占位，不可当作生产验收。

修改 native 相关代码后必须验证：

```bash
./Scripts/check-native-backend.sh
```

如果 C bridge 结构体、函数签名或 stable-diffusion.cpp 调用发生变化，必须重新构建并安装 XCFramework：

```bash
./Scripts/install-native-backend.sh /path/to/stable-diffusion.cpp
```

## 8. 构建与测试规范

每次代码变更后，至少运行以下分层检查。

### 8.1 基础静态检查

```bash
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk LocalDiffusion/App/LocalDiffusionApp.swift LocalDiffusion/Inference/ImageGenerationBackend.swift LocalDiffusion/Models/AppModels.swift LocalDiffusion/Services/AppFileStore.swift LocalDiffusion/Services/HuggingFaceDownloadManager.swift LocalDiffusion/ViewModels/GenerationViewModel.swift LocalDiffusion/Views/Gallery/GalleryView.swift LocalDiffusion/Views/Generation/GenerationView.swift LocalDiffusion/Views/Models/ModelLibraryView.swift LocalDiffusion/Views/Prompts/PromptLibraryView.swift LocalDiffusion/Views/RootContentView.swift LocalDiffusion/Views/Shared/ParameterEditor.swift
```

### 8.2 Native bridge 解析

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse -D USE_STABLE_DIFFUSION_CPP -import-objc-header LocalDiffusion/App/LocalDiffusion-Bridging-Header.h -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk LocalDiffusion/App/LocalDiffusionApp.swift LocalDiffusion/Inference/ImageGenerationBackend.swift LocalDiffusion/Models/AppModels.swift LocalDiffusion/Services/AppFileStore.swift LocalDiffusion/Services/HuggingFaceDownloadManager.swift LocalDiffusion/ViewModels/GenerationViewModel.swift LocalDiffusion/Views/Gallery/GalleryView.swift LocalDiffusion/Views/Generation/GenerationView.swift LocalDiffusion/Views/Models/ModelLibraryView.swift LocalDiffusion/Views/Prompts/PromptLibraryView.swift LocalDiffusion/Views/RootContentView.swift LocalDiffusion/Views/Shared/ParameterEditor.swift
```

### 8.3 工程与 native 预检

```bash
plutil -lint LocalDiffusion.xcodeproj/project.pbxproj
./Scripts/check-native-backend.sh
```

### 8.4 真机构建

在 Codex 沙箱内，SwiftData macro/plugin server 可能被拦截并报：

```text
sandbox-exec: sandbox_apply: Operation not permitted
external macro implementation type 'SwiftDataMacros.PersistentModelMacro' could not be found
```

这通常是执行环境限制，不一定是代码错误。需要在允许的情况下使用沙箱外 `xcodebuild` 验证：

```bash
HOME=/private/tmp/localdiffusion-xcode-home DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache xcodebuild -project LocalDiffusion.xcodeproj -scheme LocalDiffusion -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/localdiffusion-derived-iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
```

### 8.5 模拟器 smoke test

优先运行脚本：

```bash
./Scripts/smoke-test-simulator.sh
```

也可手动验证：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot <DEVICE_ID>
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus <DEVICE_ID> -b
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install <DEVICE_ID> /path/to/LocalDiffusion.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch <DEVICE_ID> com.example.LocalDiffusion
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io <DEVICE_ID> screenshot /private/tmp/localdiffusion-runcheck.png
```

验收标准：

- `xcodebuild` 输出 `BUILD SUCCEEDED`。
- `simctl install` 成功。
- `simctl launch` 返回进程号。
- 截图不是黑屏，首屏 UI 正常渲染。

最终本地推理验收还必须在真机或可运行环境中加载真实 GGUF 模型，并完成一次图像生成。

## 9. README 与记录规范

每次完成实质性工作后必须更新记录：

- 如果新增功能、用户流程或架构能力，更新 `README.md` 的 Current implementation 或相关章节。
- 如果新增/调整验证命令，更新 `README.md` 的 Verification，并同步本文件第 8 节。
- 如果改变项目规范、开发流程、已知限制，更新本 `agent.md`。
- 如果完成一轮重要任务，在 README 的“Maintenance log”追加简短记录：日期、完成内容、验证命令、剩余风险。
- 不允许只在聊天里说完成，而不把关键验收方式沉淀到文档。

建议记录格式：

```markdown
### YYYY-MM-DD

- 完成：一句话说明。
- 验证：列出实际跑过且通过的命令。
- 风险：列出没有验证或依赖外部环境的点。
```

## 10. 已知问题与注意事项

- Codex 沙箱内运行完整 `xcodebuild` 可能触发 SwiftData macro/plugin server 错误，需要沙箱外构建验证。
- Codex 沙箱内 `simctl` 可能无法访问 CoreSimulatorService，需要沙箱外执行。
- 当前 bundle id 为 `com.example.LocalDiffusion`，发布前应改成真实 bundle id。
- native backend 预检能确认链接和符号，但不能替代真实 GGUF 生成验收。
- `DEBUG_MOCK_INFERENCE` 只能说明 UI 流程可走通，不能说明 stable-diffusion.cpp 推理成功。
- 当前 UI 使用 iOS 浮动 Tab Bar，系统透明材质可能让底部略透内容；新增页面必须保留足够底部留白。

## 11. 后续优先级

优先做：

1. 真机加载小型 GGUF 模型，完成一次端到端生成。
2. 给生成流程增加更明确的 native 错误分类和用户可恢复提示。
3. 把 ModelLibraryView 拆分成更小文件，降低单文件维护成本。
4. 给 SwiftData migration 和存储损坏恢复设计可测试路径。
5. 给 smoke test 增加截图像素/文本存在性检查，而不只是截图输出。
6. 增加 README 的真实设备推理验收说明和模型推荐限制。

## 12. 交付前自检清单

回复用户“完成”前，逐项确认：

- 需求是否真的覆盖，而不是只完成容易的子集。
- 当前工作树是否有未解释改动。
- README 是否需要更新，若需要是否已更新。
- `agent.md` 的测试规范是否因本次任务变化而需要同步。
- 是否跑过对应层级测试。
- 如果没跑某项测试，是否明确说明原因和风险。
- 对 iOS UI 改动，是否至少构建通过；重大 UI 改动应尽量安装运行并截图确认。
- 对 native backend 改动，是否跑过 `check-native-backend.sh`，必要时是否重建 XCFramework。

## 13. 给后续 Codex 的启动提示词

后续启动本项目任务时，可把以下内容作为系统提示词或项目提示词：

```text
你是 Local Diffusion 项目的维护型 Codex Agent。开始前必须阅读 /Users/a114514/Desktop/codex/image ai/agent.md 和 README.md，并以当前工作树、git 状态、构建输出和运行截图为准。项目是 SwiftUI + SwiftData 的原生 iOS 本地图像生成 App，native backend 通过 stable-diffusion.cpp XCFramework 和 ImageGenerationBackend 协议接入。你必须保持当前简洁科幻暗色 UI 方向，复用 SciFiTheme 和共享组件，不回退到默认浅色/默认按钮风格。每次修改后运行匹配风险等级的验证：swiftc parse、native bridge parse、plutil、check-native-backend、xcodebuild、simulator smoke test。Codex 沙箱可能挡住 SwiftData macro 和 simctl；必要时请求沙箱外执行。完成实质性工作后必须更新 README 的完成记录/测试说明，并在测试规范变化时同步 agent.md。不要还原用户改动，不做无关重构，最终回答必须说明改了什么、验证了什么、还有什么风险。
```
