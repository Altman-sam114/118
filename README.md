# Local Diffusion

Local Diffusion is a native iOS 17 SwiftUI image generation app for fully local image inference.

## Current implementation

- SwiftUI app shell with adaptive tab navigation for iPhone and a single top-level split-view layout for iPad, including an embedded Gallery filter rail that avoids nested split views and a Plan entry for paid-capability planning status.
- SwiftData metadata models for downloaded models, generated images, folders, tags, and prompt templates.
- FileManager-backed Application Support storage for GGUF models and generated images, with files excluded from iCloud backup.
- Hugging Face GGUF download flow with paste-and-parse Hugging Face file URLs, `.gguf` source validation, local GGUF file import, progress, pause, resume, cancel, confirmed deletion, duplicate protection, persisted byte tracking, untracked-file import/cleanup, restart recovery for interrupted downloads, accessible labeled row controls, and Dynamic Type-friendly model storage rows.
- Generation screen with positive and negative prompts, Dynamic Type-friendly prompt editor headers and clear controls, shared parameter controls, steps, CFG, seed, preset or custom image size, sampler, progress, explicit cancellation state, result display, a handoff to the saved gallery result, and an iPad two-column creation console that separates inputs from run/result status while falling back to a single readable column at accessibility Dynamic Type sizes.
- Gallery grid with a Dynamic Type-friendly filter rail, readable folder/tag filters with image counts, Dynamic Type-friendly image tiles, readable metadata, clear tile accessibility labels, readable detail parameters and actions, editable folders, folder and tag filtering, date/model sorting, editable tags, folder assignment, PNG sharing, file-backed deletion, missing-file and orphan-file reconciliation, parameter reuse, one-tap regeneration, and separate requested/output image dimensions.
- Prompt library with categories, accessible labeled category and template controls, category rename/clear actions, Dynamic Type-friendly prompt rows, editable saved templates with labeled prompt editors, direct saving from the generation screen, and one-click loading into the generation screen.
- Plan screen that truthfully shows the current Local plan, states that StoreKit products are not configured, presents platform status, a capability matrix, entitlement rules, availability rows, and Mac readiness blockers with Dynamic Type-friendly status badges and explicit VoiceOver semantics, and uses an iPad regular two-column layout without enabling purchases, entitlements, or Mac Catalyst.
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

Use `agentx:`, `x:`, or `X:` to start the future controller loop for a larger goal. Agent X does not replace Agent A, Agent B, or Agent C; it splits the larger goal into small rounds and schedules the normal A -> B -> C flow until the goal is complete, blocked, paused, or returned for a fix.

The CI results workflow is `.github/workflows/ci-results.yml`. It is triggered by `main` pushes and manual dispatch, and is expected to upload a traceable artifact containing `ci-artifact-manifest.json`, `ci-failure-summary.md`, `junit.xml`, Xcode logs, native preflight logs, and the result bundle when available.

The generated native XCFramework is not committed to git. CI restores it from the GitHub Release tag `native-backend-current`, asset `LocalDiffusionNative.xcframework.zip`, checks the SHA-256 recorded in `NativeBackend/StableDiffusionCpp/native-backend-asset.json`, and only then runs native preflight and `xcodebuild`.

## Verification

Run the native preflight after installing or refreshing the XCFramework:

```bash
./Scripts/check-native-backend.sh
```

After replacing the Release asset, refresh and validate its tracked metadata:

```bash
python3 -m json.tool NativeBackend/StableDiffusionCpp/native-backend-asset.json >/dev/null
```

Run a simulator build, install, launch, and screenshot smoke test with:

```bash
./Scripts/smoke-test-simulator.sh
```

Set `DEVICE_NAME` or `DEVICE_ID` to target a different simulator. This smoke test verifies build, installation, SwiftData startup, and first-screen rendering. Final local-inference acceptance still requires running the app on a device with a real GGUF model and completing one image generation.

## Agent handoff and maintenance

Future Codex agents should read `AGENTS.md` before changing code. The project now uses a structured Agent workflow:

- `AGENTS.md`: project entry memory, rules, architecture boundaries, Agent A/B/C/X workflow.
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

### 2026-07-05

- Completed: Refined Plan availability rows so core Local tools and the blocked Purchase UI condition use the same readable status-row pattern and VoiceOver label/value semantics as the rest of Plan.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.19 version.
- Risk: This is presentation-only; no StoreKit purchase flow, entitlement persistence, Mac Catalyst support, native backend, or simulator VoiceOver QA is added.
- Completed: Refined Plan accessibility semantics so the Local Plan overview and status rows expose clear VoiceOver label/value pairs while preserving the existing paid/Mac planning facts.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.18 version.
- Risk: This is presentation-only; no StoreKit purchase flow, entitlement persistence, Mac Catalyst support, native backend, or simulator VoiceOver QA is added.

### 2026-07-04

- Completed: Refined Gallery filter rail rows so All Images, folder, and tag filters show image counts, keep readable 44pt rows, and expose clearer VoiceOver semantics at Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.17 version.
- Risk: This is presentation-only; no Gallery filtering, sorting, folder/tag mutation, image grid/detail behavior, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Gallery image details so long prompts, negative prompts, parameter rows, tags, and reuse/regenerate/share/save actions stay readable and accessible at Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.16 version.
- Risk: This is presentation-only; no Gallery filtering, sorting, reuse, regeneration, deletion, file storage, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Generate prompt editors so headers, character counts, clear controls, placeholders, and text editor accessibility remain readable at Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.15 version.
- Risk: This is presentation-only; no prompt semantics, generation behavior, template saving, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined the Prompt template editor so positive and negative prompt fields use visible labels, placeholders, character counts, Sci-Fi panel styling, and taller Dynamic Type-friendly editing areas.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.14 version.
- Risk: This is presentation-only; no template schema, save/load behavior, generation parameters, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined shared parameter controls so Seed/Size/CFG rows, status pills, and metric cards use clearer accessibility labels and reduce horizontal compression at accessibility Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.13 version.
- Risk: This is presentation-only; no parameter defaults, ranges, normalization, generation behavior, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Gallery image tiles so the grid uses wider columns at accessibility Dynamic Type sizes, tile metadata stacks when needed, prompt text gets more room, and VoiceOver gets a useful generated-image summary.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.12 version.
- Risk: This is presentation-only; no Gallery filtering, sorting, reuse, regeneration, deletion, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Prompt Library category and template row controls so icon-only menu/edit/load actions expose readable labels, keep 44pt hit areas, and stack template rows at accessibility Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.11 version.
- Risk: This is presentation-only; no template loading, editing, category mutation, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Models row controls so icon-only buttons now expose readable labels for assistive technologies, keep 44pt hit areas, and stack storage/model/untracked-file rows at accessibility Dynamic Type sizes.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.10 version.
- Risk: This is presentation-only; no download, import, delete, StoreKit, Mac Catalyst, native backend, or simulator screenshot QA is added.
- Completed: Refined Generate so iPad regular uses the two-column creation console only at non-accessibility Dynamic Type sizes; accessibility text sizes now use a single-column Generate layout with stacked console header, status pills, and metrics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.9 version.
- Risk: This is presentation-only; no generation behavior, StoreKit behavior, Mac Catalyst support, or simulator screenshot QA is added.
- Completed: Refined Plan status rows so current build, platform status, Mac readiness, capability matrix, and entitlement rules use Dynamic Type-friendly status badges; accessibility text sizes now use a single-column Plan layout and stacked overview header.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.8 version.
- Risk: This is presentation-only; no StoreKit behavior, Mac Catalyst support, or simulator screenshot QA is added.
- Completed: Added a Plan entitlement rules baseline that protects current Local tools, marks paid candidates as planning-only, and records StoreKit/product/entitlement prerequisites before any purchase UI can exist.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.7 version.
- Risk: This is still UI/documentation only; StoreKit, product IDs, purchase state persistence, and entitlement enforcement remain unimplemented.
- Completed: Added an iPad regular two-column Plan layout so Local plan status, platform status, Mac blockers, capability matrix, and availability notes are easier to scan without changing compact Form behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.6 version.
- Risk: This is presentation-only; StoreKit remains unconfigured and Mac Catalyst remains disabled.
- Completed: Added a Mac readiness checklist to Plan, covering Xcode platform configuration, native Mac/Catalyst backend slice work, window/sidebar QA, and distribution/signing decisions.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.5 version.
- Risk: This remains planning UI only; Mac Catalyst is still disabled and the native XCFramework still needs a Mac/Catalyst slice before a real Mac build.
- Completed: Added a Plan capability matrix that separates current Local features, planned paid candidates, and StoreKit configuration-gated work without purchase actions or entitlements.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.4 version.
- Risk: The matrix is informational only; StoreKit products, prices, entitlement rules, and paid access remain unimplemented.
- Completed: Added a Mac platform status baseline to Plan and documentation. The app now reports iPhone/iPad availability and Mac Catalyst as not enabled until Xcode platform settings, native backend slices, signing, and UI validation are handled.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.3 version.
- Risk: This does not enable a Mac build; the native XCFramework currently contains only iOS and iOS simulator slices.
- Completed: Added a Plan navigation entry and local paid-capability baseline. The screen reports the current Local plan, StoreKit-not-configured status, and future paid-capability candidates without purchase UI or entitlements.
- Verified: Local lightweight checks and cloud CI artifact review are required for the v1.2 version.
- Risk: Real paid features still require product IDs, entitlement rules, StoreKit implementation, and App Store Connect configuration.
- Completed: Added the Agent X documentation baseline for future controller-loop iteration. Agent X can be summoned with `agentx:`, but it must still schedule Agent A prompts, Agent B implementation pushes, and Agent C artifact review rather than replacing them.
- Verified: Documentation-only change; `git diff --check` is the required local validation for this version.
- Risk: This prepares the workflow only. It does not start an actual Agent X loop or change app behavior.
- Completed: Added native Release asset checksum metadata and CI verification before XCFramework unzip.
- Verified: Local lightweight checks are required; cloud CI must expose `native-backend-asset.log` in the result artifact.
- Risk: The metadata must be refreshed whenever the Release asset is replaced.

### 2026-07-03

- Completed: Upgraded the collaboration workflow to local lightweight checks, `main` direct push, GitHub Actions cloud validation, and Agent C artifact review.
- Verified: Governance and CI scaffold change; local lightweight checks are required for this version.
- Risk: Cloud CI depends on the `native-backend-current` Release asset staying present and matching the checked-in bridge ABI.
- Completed: Adjusted cloud CI to restore the ignored native XCFramework from a GitHub Release asset before native preflight and Xcode build.

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
