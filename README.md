# Local Diffusion

Local Diffusion is a native iOS 17 SwiftUI image generation app for fully local image inference.

## Current implementation

- SwiftUI app shell with adaptive tab and split-view navigation for iPhone and iPad.
- SwiftData metadata models for downloaded models, generated images, folders, tags, and prompt templates.
- FileManager-backed Application Support storage for GGUF models and generated images, with files excluded from iCloud backup.
- Hugging Face GGUF download flow with paste-and-parse Hugging Face file URLs, `.gguf` source validation, local GGUF file import, progress, pause, resume, cancel, confirmed deletion, duplicate protection, persisted byte tracking, untracked-file import/cleanup, and restart recovery for interrupted downloads.
- Generation screen with positive and negative prompts, steps, CFG, seed, preset or custom image size, sampler, progress, explicit cancellation state, result display, and a handoff to the saved gallery result.
- Gallery grid with editable folders, folder and tag filtering, date/model sorting, detail parameters, editable tags, folder assignment, PNG sharing, file-backed deletion, missing-file and orphan-file reconciliation, parameter reuse, one-tap regeneration, and separate requested/output image dimensions.
- Prompt library with categories, category rename/clear actions, editable saved templates, direct saving from the generation screen, and one-click loading into the generation screen.
- Inference protocol boundary plus an explicit unavailable-backend error when native inference is not linked, an opt-in `DEBUG_MOCK_INFERENCE` placeholder backend for development, a conditional stable-diffusion.cpp XCFramework C bridge, and an Objective-C++ native bridge matched to current stable-diffusion.cpp image-generation APIs with progress and cancellation propagation.

## Native inference integration

The UI talks only to `ImageGenerationBackend`. `InferenceBackendFactory` uses `StableDiffusionCPPInferenceBackend` when `USE_STABLE_DIFFUSION_CPP` is enabled by `LocalDiffusion/Config/NativeBackend.xcconfig`. Without that flag, generation fails with an explicit backend-not-linked error. Add `DEBUG_MOCK_INFERENCE` only for UI development placeholder images.

The intended production path is:

1. Check out `stable-diffusion.cpp` with submodules.
2. Build, install, link, and enable the native backend:
   `./Scripts/install-native-backend.sh /path/to/stable-diffusion.cpp`
3. Run `./Scripts/check-native-backend.sh` to verify the framework, bridge symbols, Xcode target linkage, and compile flag.
4. Build the app normally from Xcode or with `xcodebuild`.

For manual packaging, `./Scripts/build-stable-diffusion-xcframework.sh /path/to/stable-diffusion.cpp ./LocalDiffusionNative.xcframework` creates the XCFramework without modifying the app project.

## Build note

The native build scripts require CMake and full Xcode. If the active developer directory points at Command Line Tools, the scripts automatically use `/Applications/Xcode.app` when it is present.

## Verification

Run the native preflight after installing or refreshing the XCFramework:

```bash
./Scripts/check-native-backend.sh
```

Run a simulator build, install, launch, and screenshot smoke test with:

```bash
./Scripts/smoke-test-simulator.sh
```

Set `DEVICE_NAME` or `DEVICE_ID` to target a different simulator. This smoke test verifies build, installation, SwiftData startup, and first-screen rendering. Final local-inference acceptance still requires running the app on a device with a real GGUF model and completing one image generation.

## Agent handoff and maintenance

Future Codex agents should read `agent.md` before changing code. That file is the project handoff prompt, development rulebook, UI direction, validation checklist, and documentation-update policy.

After every meaningful coding task:

- Update this README when behavior, setup, verification, or completion status changes.
- Update `agent.md` when the development or testing rules change.
- Record what was completed, what was verified, and what remains risky.

## Maintenance log

### 2026-06-27

- Completed: Added `agent.md` as the structured project summary, Codex system prompt, coding rules, UI direction, validation checklist, and ongoing documentation policy.
- Verified: Read current README, git status/log, project scripts, and current file layout. Current git HEAD observed as `499f450 (main) 1` at the time of writing.
- Risk: This documentation records the current local repository state only; future agents must re-check git status and build outputs before acting.
