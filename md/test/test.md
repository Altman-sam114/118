# 测试规范

本文指导 Agent B 和 Agent C 按改动风险选择测试。每次实现前先读本文件。

## 固定前缀 / 环境要求

项目依赖：

- full Xcode，优先使用 `/Applications/Xcode.app/Contents/Developer`
- iOS SDK 和 iOS Simulator runtime
- SwiftData macro/plugin server
- native backend 预检需要 `xcrun`、`nm`、`lipo`
- simulator smoke test 需要 CoreSimulatorService 可用

推荐环境变量：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache
```

Codex 沙箱注意：

- 沙箱内完整 `xcodebuild` 可能因 SwiftData macro/plugin server 失败。
- 沙箱内 `simctl` 可能无法访问 CoreSimulatorService。
- 遇到上述情况，不要判断为代码错误；需要请求沙箱外执行并记录原因。

## 测试分层

### 1. Probe / Fast

最快发现主链路断点。

触发条件：

- 任意 Swift 源码变更。
- SwiftUI 文档化规则涉及具体代码行为。
- 需要快速确认语法和桥接头是否破损。

命令：

```bash
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk LocalDiffusion/App/LocalDiffusionApp.swift LocalDiffusion/Inference/ImageGenerationBackend.swift LocalDiffusion/Models/AppModels.swift LocalDiffusion/Services/AppFileStore.swift LocalDiffusion/Services/HuggingFaceDownloadManager.swift LocalDiffusion/ViewModels/GenerationViewModel.swift LocalDiffusion/Views/Gallery/GalleryView.swift LocalDiffusion/Views/Generation/GenerationView.swift LocalDiffusion/Views/Models/ModelLibraryView.swift LocalDiffusion/Views/Prompts/PromptLibraryView.swift LocalDiffusion/Views/RootContentView.swift LocalDiffusion/Views/Shared/ParameterEditor.swift
```

```bash
CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse -D USE_STABLE_DIFFUSION_CPP -import-objc-header LocalDiffusion/App/LocalDiffusion-Bridging-Header.h -target arm64-apple-ios17.0 -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk LocalDiffusion/App/LocalDiffusionApp.swift LocalDiffusion/Inference/ImageGenerationBackend.swift LocalDiffusion/Models/AppModels.swift LocalDiffusion/Services/AppFileStore.swift LocalDiffusion/Services/HuggingFaceDownloadManager.swift LocalDiffusion/ViewModels/GenerationViewModel.swift LocalDiffusion/Views/Gallery/GalleryView.swift LocalDiffusion/Views/Generation/GenerationView.swift LocalDiffusion/Views/Models/ModelLibraryView.swift LocalDiffusion/Views/Prompts/PromptLibraryView.swift LocalDiffusion/Views/RootContentView.swift LocalDiffusion/Views/Shared/ParameterEditor.swift
```

当前基线：

- 两条 Swift parse 命令应返回 0。

### 2. Smoke

验证主要集成路径。

触发条件：

- UI 导航、启动流程、SwiftData container、模型列表、生成入口、Tab/Sidebar 改动。
- README 或测试规范声称 app 可安装/启动。

命令：

```bash
./Scripts/smoke-test-simulator.sh
```

当前基线：

- simulator build 成功。
- app 安装成功。
- `simctl launch` 返回进程号。
- 生成截图，且首屏不是黑屏。

### 3. Stage Regression

覆盖当前阶段核心模块。

触发条件：

- native backend、Xcode project、桥接头、XCFramework、构建配置变化。
- 下载、文件存储、SwiftData 模型、生成保存链路变化。
- 影响多个页面或跨层状态流。

命令：

```bash
plutil -lint LocalDiffusion.xcodeproj/project.pbxproj
./Scripts/check-native-backend.sh
HOME=/private/tmp/localdiffusion-xcode-home DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache xcodebuild -project LocalDiffusion.xcodeproj -scheme LocalDiffusion -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/localdiffusion-derived-iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
```

当前基线：

- project plist lint 为 OK。
- native backend preflight 全部 PASS。
- iPhoneOS Debug 构建 `BUILD SUCCEEDED`。

### 4. Full

全量测试。

触发条件：

- 发布前。
- native bridge ABI、stable-diffusion.cpp 集成或生成主链路大改。
- SwiftData schema 或文件存储结构大改。
- Agent C 判断 Smoke/Stage 不能覆盖风险。

命令：

```bash
./Scripts/check-native-backend.sh
./Scripts/smoke-test-simulator.sh
HOME=/private/tmp/localdiffusion-xcode-home DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/localdiffusion-clang-cache xcodebuild -project LocalDiffusion.xcodeproj -scheme LocalDiffusion -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/localdiffusion-derived-full-iphoneos CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
```

真实推理验收：

- 在真机或可运行环境导入真实 GGUF 模型。
- 生成一张图片。
- 确认图片文件保存到 Application Support。
- 确认 SwiftData 中生成记录、尺寸、prompt、model id、tags 可在 Gallery 读取。

当前基线：

- 构建、安装、启动和截图 smoke 可通过。
- 真实 GGUF 端到端生成仍待人工或后续版本确认。

## 静态检查

文档-only 修改至少运行：

```bash
git diff --check
```

工程文件变化运行：

```bash
plutil -lint LocalDiffusion.xcodeproj/project.pbxproj
```

UI 默认样式回退检查可运行：

```bash
grep -R -n "ContentUnavailableView\|foregroundStyle(.secondary)\|buttonStyle(.bordered\|regularMaterial" LocalDiffusion/Views LocalDiffusion/App
```

## 规则

- 每次实现前先读本文件。
- 默认从最小测试开始。
- 根据改动范围扩大测试。
- 不得伪造测试结果。
- 必须记录具体命令和退出结果。
- 文档-only 修改可只跑静态检查，但必须说明未跑完整业务测试的原因。
- 沙箱环境失败必须区分“环境限制”和“代码失败”。
