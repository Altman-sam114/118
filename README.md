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

## Collaboration and cloud validation

Agent workflow now defaults to `main` direct push and GitHub Actions revalidation. Agent B runs local lightweight checks, commits the versioned change on `main`, and pushes to `origin/main`. Agent C must download the unencrypted CI results artifact, check its manifest, logs, JUnit summary, run id, and commit SHA, then accept the latest `origin/main` run or return the work for an additional fix commit.

The CI results workflow is `.github/workflows/ci-results.yml`. It is triggered by `main` pushes and manual dispatch, and is expected to upload a traceable artifact containing `ci-artifact-manifest.json`, `ci-failure-summary.md`, `junit.xml`, Xcode logs, native preflight logs, and the result bundle when available.

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

Future Codex agents should read `AGENTS.md` before changing code. The project now uses a structured Agent workflow:

- `AGENTS.md`: project entry memory, rules, architecture boundaries, Agent A/B/C workflow.
- `update_log.md`: version history, decisions, completed work, known leftovers.
- `md/flow/flow.md`: current core logic and runtime flow.
- `md/flow/flowchart.md`: Mermaid diagrams for data flow, execution flow, and Agent iteration flow.
- `md/test/test.md`: test layers, commands, triggers, and current baselines.
- `md/prompt/`: versioned Agent A prompts for Agent B implementation.
- `.github/workflows/ci-results.yml`: cloud validation and unencrypted Agent C results artifact.

After every meaningful coding task:

- Update this README when behavior, setup, verification, or completion status changes.
- Update `AGENTS.md`, `md/test/test.md`, or `md/flow/**` when development rules, test rules, or core logic change.
- Record what was completed, what was verified, and what remains risky.
- By default, Agent B commits the versioned change on `main` and pushes to `origin/main`; Agent C accepts only the latest matching GitHub Actions run and results artifact.

## Maintenance log

### 2026-07-03

- Completed: Upgraded the collaboration workflow to local lightweight checks, `main` direct push, GitHub Actions cloud validation, and Agent C artifact review.
- Verified: Governance and CI scaffold change; local lightweight checks are required for this version.
- Risk: The local repository currently has no `origin`, so the first real cloud run requires configuring the remote and GitHub Actions access.

### 2026-06-29

- Completed: Added the Agent C acceptance gate for version commits. Accepted versions must be committed with a concise versioned message; rejected versions return to Agent B without a commit.
- Verified: Documentation-only change; `git diff --check` passed.
- Risk: This changes governance only and does not validate business runtime behavior.

### 2026-06-28

- Completed: Replaced the old single-file `agent.md` handoff with the standard `AGENTS.md` + `update_log.md` + `md/prompt` + `md/test` + `md/flow` multi-Agent iteration system.
- Verified: Read current README, git status/log, key scripts, App entry, navigation, generation view model, and backend boundary before writing the docs.
- Risk: Documentation-only change; business build/smoke tests are not required unless source code changes.

### 2026-06-27

- Completed: Added `agent.md` as the structured project summary, Codex system prompt, coding rules, UI direction, validation checklist, and ongoing documentation policy.
- Verified: Read current README, git status/log, project scripts, and current file layout. Current git HEAD observed as `499f450 (main) 1` at the time of writing.
- Risk: This documentation records the current local repository state only; future agents must re-check git status and build outputs before acting.
