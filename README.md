# Local Diffusion

Local Diffusion is a native iOS 17 SwiftUI image generation app for fully local image inference.

## Current implementation

- SwiftUI app shell with adaptive tab navigation for iPhone and a single top-level split-view layout for iPad, including accessible sidebar rows with pointer hover affordance, an embedded Gallery filter rail that avoids nested split views, and a neutral planning/checklist Plan entry whose sidebar hint covers local plan, planning-only paid capability status, and platform readiness.
- SwiftData metadata models for downloaded models, generated images, folders, tags, and prompt templates.
- FileManager-backed Application Support storage for GGUF models and generated images, with files excluded from iCloud backup.
- Hugging Face GGUF download flow with paste-and-parse Hugging Face file URLs, keyboard-aware Add Model submission, Add Model field-level VoiceOver labels/values/hints for URL, display name, repository, GGUF file path or direct URL, revision, and family, `.gguf` source validation, toolbar refresh/add menu VoiceOver context, local GGUF file import, progress, pause, resume, cancel, confirmed deletion with model-name/count VoiceOver context, duplicate protection, persisted byte tracking, untracked-file import/cleanup with file-specific VoiceOver actions and filename-aware delete confirmation semantics, an untracked GGUF import editor with display-name and family field VoiceOver semantics plus Import/Cancel ready and display-name-required toolbar semantics, restart recovery for interrupted downloads, accessible labeled row controls and detail sheet action buttons with model-name context, detail Native Loading mode and auxiliary model picker current-value VoiceOver context, empty-state VoiceOver context for no tracked models or untracked GGUF files plus the download/import next steps, readable Add Model errors, readable model list and detail status messages, and Dynamic Type-friendly model storage rows with a combined VoiceOver storage summary.
- Generation screen with positive and negative prompts, Dynamic Type-friendly prompt editor headers with field-specific character-count VoiceOver semantics and clear controls, Save Template toolbar readiness and prompt-required VoiceOver semantics, shared parameter controls with reset-defaults scope, prompt-preservation semantics, seed field editing hints, random seed current-value hints, canvas size preset hints for width/height updates plus editable custom dimensions, width/height hints for canvas pixel dimensions, sampler picker hints for choosing the sampling algorithm, steps hints for denoising-step adjustment, CFG hints for prompt guidance strength, VoiceOver-aware generation readiness, no-model empty-state summary semantics plus Open Models next-step semantics with a 44pt hit area, model picker current-selection and ready-model-count semantics, ready/blocked run action and next-step semantics, progress/cancel/result semantics, explicit cancellation state, result display, a Gallery handoff that names the saved result entry and distinguishes saved versus unavailable Gallery records, and an iPad two-column creation console that separates inputs from run/result status while summarizing backend/model readiness for VoiceOver and falling back to a single readable column at accessibility Dynamic Type sizes or constrained regular-width windows.
- Gallery grid with a Dynamic Type-friendly filter rail, readable folder/tag filters with image counts and pointer hover affordance, folder rename/delete actions with folder-name VoiceOver context, folder delete confirmation button VoiceOver context for confirming or cancelling folder deletion, folder editor name-field VoiceOver semantics plus Save/Cancel ready and name-required toolbar semantics, empty-state VoiceOver context for the active filter, Dynamic Type-friendly image tiles with pointer hover affordance, readable metadata, prompt-focused tile accessibility labels with model/date/output metadata values, readable detail parameters/actions/organization controls with image-context VoiceOver values, image delete confirmation button VoiceOver context for confirming or cancelling deletion, Folder picker VoiceOver context for immediate selection saving, Save Tags VoiceOver state for draft tags, saved tags, and unsaved changes, editable folders, folder and tag filtering, date/model sorting with current sort VoiceOver value, editable tags, folder assignment, PNG sharing, file-backed deletion, missing-file and orphan-file reconciliation, parameter reuse, one-tap regeneration, and separate requested/output image dimensions.
- Prompt library with categories, category headings that expose the current visible template count after filtering, an Add prompt template toolbar action that exposes ready state and opens a new template editor using the current generation parameters, a search field with search-submit semantics and VoiceOver context for template name/category/prompt matching, category action menus with pointer hover affordance and category-aware VoiceOver context, category clear confirmation buttons with category-name confirm/cancel VoiceOver semantics, row-level template summaries that expose positive prompt, negative prompt, category, steps, sampler, and canvas size while preserving Edit/Load controls, accessible labeled template controls with template-name context, template metric pills that expose steps, sampler, and canvas size context to VoiceOver, category rename/clear actions, VoiceOver-aware empty and search-empty states, Dynamic Type-friendly prompt rows, editable saved templates with labeled prompt editors, template name/category field VoiceOver semantics, field-specific prompt character-count VoiceOver semantics, category rename name-field semantics, Save/Cancel ready and name-required VoiceOver semantics, direct saving from the generation screen, and one-click loading into the generation screen.
- Plan screen that truthfully shows the current Local plan, uses a neutral planning/checklist overview icon instead of a payment-coded icon, states that StoreKit products are not configured, uses the overview note/value/hint and Current Build purchase note to clarify that paid candidates on the screen are planning only and cannot be bought or unlocked here, presents platform status with summary row VoiceOver hints and a Mac support note that keeps Mac/Catalyst support planned and not enabled while the iPhone/iPad app remains available and says there is no separate Mac binary, Mac signing profile, sandbox entitlement, or notarization pipeline, a capability matrix with paid candidates marked planning-only and StoreKit purchases marked not enabled/not selling, purchasing, or unlocking paid candidates, entitlement rules with row-level VoiceOver hints including paid candidates that grant no trial entitlement, preview entitlement, feature flag, or unlock gate, entitlement persistence that has no local cache, cross-launch restoration, server-side entitlement source, or receipt-backed state, plus a StoreKit purchase gate that does not request an App Store product and has no restore button, receipt validation path, or entitlement mapping resolution until StoreKit prerequisites are configured, availability rows including paid candidates as planning-only, Purchase UI hidden with no purchase sheet, buy button, unlock entry point, restore entry point, manage subscription entry point, or product loading state until StoreKit products, entitlement mapping, and restore/receipt decisions exist, and Mac app status that says the iPhone/iPad app is available while Mac/Catalyst is not enabled with no separate Mac binary, Catalyst entitlement set, or desktop distribution channel plus Availability footer context, readable note rows, and Mac readiness blockers with footer context that separates the available iPhone/iPad app from the not-enabled Mac/Catalyst app, Dynamic Type-friendly status badges including Apple platform support that states this build is still iPhone/iPad app target only, native backend slice status that states the native inference framework still needs a Mac or Catalyst slice, `Needs QA` window/sidebar QA validation that says current iPad layout and pointer affordance do not replace dedicated Mac/Catalyst window/sidebar/keyboard/pointer validation, and signing/distribution status that states Mac release channel, signing, sandboxing, and notarization still need a product decision while no Mac signing profile, sandbox entitlement, or notarization pipeline exists, explicit VoiceOver semantics, compact section footer note context, and iPad panel heading/note landmarks, and uses an iPad regular two-column layout without enabling purchases, entitlements, or Mac Catalyst.
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

### 2026-07-07

- Completed: Added a Generate iPad regular-width layout fallback so the creation console prefers two columns but can fall back to the existing single readable column when horizontal space is constrained.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.120 version.
- Risk: This is Generate layout selection only; no section content, generation gate, model selection, parameter editing, native backend, SwiftData schema, file storage, Gallery handoff, StoreKit, Mac Catalyst, Xcode project, workflow behavior, or real Stage Manager screenshot validation is changed.
- Completed: Added a combined VoiceOver summary to the Generate render console status pills so backend readiness and selected model readiness are available as one console status.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.119 version.
- Risk: This is Generate console accessibility semantics only; no generation gate, model selection, parameter editing, native backend, SwiftData schema, file storage, Gallery handoff, StoreKit, Mac Catalyst, Xcode project, workflow behavior, or real VoiceOver device validation is changed.
- Completed: Refined the Plan Platform Status Mac support note so it says this build has no separate Mac binary, Mac signing profile, sandbox entitlement, or notarization pipeline.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.118 version.
- Risk: This is Plan Platform Status Mac distribution-pipeline copy and accessibility semantics only; no Mac Catalyst, separate Mac target, Mac signing profile, sandbox entitlement, notarization pipeline, Xcode project platform settings, native Mac/Catalyst slice, StoreKit, SwiftData schema, native backend, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Plan Mac Readiness Distribution and signing row so it says this build has no Mac signing profile, sandbox entitlement, or notarization pipeline.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.117 version.
- Risk: This is Plan Mac signing/distribution boundary copy and accessibility semantics only; no Mac Catalyst, separate Mac target, Mac signing profile, sandbox entitlement, notarization pipeline, Xcode project platform settings, native Mac/Catalyst slice, StoreKit, SwiftData schema, native backend, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Plan Availability Mac app row so it says this build has no separate Mac binary, Catalyst entitlement set, or desktop distribution channel.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.116 version.
- Risk: This is Plan Mac app boundary copy and accessibility semantics only; no Mac Catalyst, separate Mac target, Xcode project platform settings, signing, sandboxing, notarization, native Mac/Catalyst slice, StoreKit, SwiftData schema, native backend, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Plan Availability Purchase UI row so it says this build has no restore entry point, manage subscription entry point, or product loading state.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.115 version.
- Risk: This is Plan Purchase UI boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, subscription management, product loading, receipts, entitlement persistence, paid gate, feature flag, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Entitlement Rules StoreKit purchase gate row so it says this build has no restore button, receipt validation path, or entitlement mapping resolution.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.114 version.
- Risk: This is Plan StoreKit gate boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, paid gate, feature flag, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Entitlement Rules Entitlement persistence row so it says this build has no local entitlement cache, cross-launch restoration, server-side entitlement source, or receipt-backed state.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.113 version.
- Risk: This is Plan entitlement persistence boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, paid gate, feature flag, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Entitlement Rules Paid candidates row so it says Batch queue, curated prompt packs, and workflow export grant no trial entitlement, preview entitlement, feature flag, or unlock gate in this build.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.112 version.
- Risk: This is Plan paid candidate entitlement-boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, paid gate, feature flag, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Availability Purchase UI row so it says this build has no purchase sheet, buy button, or unlock entry point until StoreKit products, entitlement mapping, and restore/receipt decisions exist.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.111 version.
- Risk: This is Plan Purchase UI boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, paid gate, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Mac Readiness Window and sidebar QA detail and VoiceOver hint so current iPad layout and pointer affordance do not imply dedicated Mac/Catalyst validation is complete.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.110 version.
- Risk: This is Plan Mac readiness copy and accessibility semantics only; no Mac Catalyst, Xcode project platform settings, native Mac/Catalyst slice, signing, notarization, StoreKit, entitlement persistence, SwiftData schema, native backend, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Plan overview note, value, and hint so the first Plan panel says no purchase state, entitlement, or App Store product request exists and paid candidates cannot be bought or unlocked here.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.109 version.
- Risk: This is Plan overview purchase-boundary copy and accessibility semantics only; no StoreKit products, purchase UI, restore flow, receipts, subscriptions, entitlement persistence, paid gate, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Added field-level VoiceOver labels, values, and hints to the Models Add Model Hugging Face URL, display name, repository, GGUF file path or direct URL, revision, and family fields while preserving URL parsing and download behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.108 version.
- Risk: This is Models Add Model field accessibility semantics only; no URL parsing, download state machine, untracked file scan/import/delete behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added field-level VoiceOver label, value, and hint to the Gallery folder editor name field while preserving folder save behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.107 version.
- Risk: This is Gallery folder editor field accessibility semantics only; no folder create/rename/delete/filter/sort behavior, image folder assignment, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added field-level VoiceOver labels, values, and hints to the Models untracked GGUF import editor display name field and family picker while preserving import behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.106 version.
- Risk: This is Models untracked import editor field accessibility semantics only; no untracked file scan/import/delete behavior, download state machine, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Prompt Library category heading VoiceOver semantics so each category title is navigable as a header and exposes the current visible template count after search filtering.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.105 version.
- Risk: This is Prompt Library category title accessibility semantics only; no template save/load/search/category behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Expanded Prompt template row VoiceOver summaries so each row includes positive prompt, negative prompt, category, steps, sampler, and canvas size while preserving visible row layout and Edit/Load controls.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.104 version.
- Risk: This is Prompt Library row summary accessibility semantics only; no template save/load/search/category behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added VoiceOver labels, values, and hints to Prompt template name/category fields and the category rename name field while preserving save trimming and disabled-state behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.103 version.
- Risk: This is Prompt Library metadata input accessibility semantics only; no template save/load/search/category behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.

### 2026-07-06

- Completed: Added field-specific VoiceOver labels and values to Prompt template editor prompt character counts while preserving visible count text and template editing behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.102 version.
- Risk: This is Prompt template editor character-count accessibility semantics only; no template save/load/search/category behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added field-specific VoiceOver labels and values to Generate prompt header character counts while preserving visible count text and prompt editor behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.101 version.
- Risk: This is Generate prompt character-count accessibility semantics only; no prompt binding, focus, clear action, generation gate, model selection, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added call-site VoiceOver summary semantics to the Generate no-model empty-state card while preserving the shared empty-state component and Open Models action.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.100 version.
- Risk: This is Generate no-model empty-state accessibility semantics only; no model query, model selection, generation gate, download/import flow, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added saved-result VoiceOver label, saved/unavailable value, and state-specific hints to the Generate result `View in Gallery` button while preserving Gallery handoff behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.99 version.
- Risk: This is Generate result Gallery handoff accessibility semantics only; no generation save data flow, Gallery navigation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added filename VoiceOver labels, values, and hints to Models untracked file delete confirmation buttons while preserving local file deletion behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.98 version.
- Risk: This is Models untracked file delete confirmation accessibility semantics only; no untracked delete data flow, tracked model delete flow, download state machine, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added model-name/count VoiceOver labels, values, and hints to Models tracked model delete confirmation buttons while preserving metadata/file deletion behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.97 version.
- Risk: This is Models tracked model delete confirmation accessibility semantics only; no delete data flow, untracked file delete flow, download state machine, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added category-name VoiceOver labels, values, and hints to Prompt Library category clear confirmation buttons while preserving template retention and Uncategorized migration behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.96 version.
- Risk: This is Prompt category clear confirmation accessibility semantics only; no template clear behavior, edit/load/save/search/grouping, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added folder-name VoiceOver labels, values, and hints to Gallery folder delete confirmation buttons while preserving folder deletion behavior and image retention.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.95 version.
- Risk: This is Gallery folder delete confirmation accessibility semantics only; no folder deletion data flow, image retention, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added image-context VoiceOver labels, values, and hints to Gallery detail delete confirmation buttons while preserving destructive/cancel roles and deletion behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.94 version.
- Risk: This is Gallery delete confirmation accessibility semantics only; no delete flow, file storage, SwiftData schema, navigation cleanup, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Clarified Gallery detail Folder picker VoiceOver hint so it says folder selection saves immediately while keeping the existing folder binding behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.93 version.
- Risk: This is Gallery detail folder picker accessibility hint only; no folder binding, folder filters, folder editor, tag saving, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Expanded Gallery detail Save Tags VoiceOver state so it exposes unsaved status, draft tags, and saved tags while keeping folder and tag save behavior unchanged.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.92 version.
- Risk: This is Gallery detail organization accessibility semantics only; no tag parsing, folder binding, filtering, sorting, detail actions, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Split Gallery image tile VoiceOver output into prompt-focused labels and metadata values for model, created date, and output size.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.91 version.
- Risk: This is Gallery image tile semantics only; no filtering, sorting, navigation, thumbnail loading, detail actions, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added row-level VoiceOver summaries to Prompt Library template rows while preserving separate Edit/Load controls and metric pill semantics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.90 version.
- Risk: This is Prompt template row summary semantics only; no template query, search, grouping, sorting, edit, load, delete, save behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added current-value VoiceOver context to Models detail Native Loading mode and CLIP/T5/VAE auxiliary model pickers.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.89 version.
- Risk: This is Models detail native loading picker semantics only; no auxiliary file filtering, binding save behavior, generation logic, native backend, SwiftData schema, StoreKit, Mac Catalyst, Xcode project, or workflow behavior is changed.
- Completed: Added model-name VoiceOver context to Models detail sheet action buttons for delete, pause, cancel, resume, and download actions.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.88 version.
- Risk: This is Models detail action semantics only; no download state machine, delete behavior, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Prompt Library Add toolbar VoiceOver semantics so the action is named Add prompt template, exposes Ready state, and says it opens a new template editor using current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.87 version.
- Risk: This is Prompt Library Add toolbar semantics only; no template creation logic, save fields, search, category behavior, load behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Refined the Plan Current Build StoreKit purchase note so it says paid candidates on the screen are planning only and the VoiceOver hint says they cannot be bought or unlocked here.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.86 version.
- Risk: This is Plan Current Build purchase note copy only; no StoreKit products, purchase UI, restore flow, receipts, subscriptions, entitlement persistence, paid gate, Mac Catalyst, Xcode project platform settings, native backend, SwiftData schema, workflow behavior, or real StoreKit validation is changed.
- Completed: Refined the Plan Platform Status Mac support note so it says Mac support remains planned, the iPhone and iPad app is available, and Mac/Catalyst is not enabled until platform, native backend, signing, and UI validation prerequisites are ready.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.85 version.
- Risk: This is Plan Platform Status Mac support note copy only; no Mac Catalyst, Xcode project platform settings, native Mac/Catalyst slice, signing, notarization, SwiftData schema, workflow behavior, StoreKit, or real Mac validation is changed.
- Completed: Refined the Plan Mac Readiness footer so it states the current iPhone and iPad app is available while a Mac or Catalyst app is not enabled.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.84 version.
- Risk: This is Plan Mac readiness footer copy only; no Mac Catalyst, Xcode project platform settings, native Mac/Catalyst slice, signing, notarization, SwiftData schema, workflow behavior, StoreKit, or real Mac validation is changed.
- Completed: Refined the Plan Availability Mac app detail so it states the iPhone and iPad app is available while Mac or Catalyst support is not enabled.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.83 version.
- Risk: This is Plan Mac availability copy only; no Mac Catalyst, Xcode project platform settings, native Mac/Catalyst slice, signing, notarization, SwiftData schema, workflow behavior, StoreKit, or real Mac validation is changed.
- Completed: Refined the Plan Capability Matrix StoreKit purchases detail so it states StoreKit purchase capability is not enabled and planning-only paid candidates are not sold, purchased, or unlocked in this build.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.82 version.
- Risk: This is Plan capability copy only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, purchase flow, paid gate, SwiftData schema, workflow behavior, Mac Catalyst, or real StoreKit validation is changed.
- Completed: Refined the Plan Entitlement Rules StoreKit purchase gate detail so it states no App Store product is requested until StoreKit prerequisites are configured.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.81 version.
- Risk: This is Plan entitlement copy only; no StoreKit products, purchase UI, restore flow, receipts, entitlement persistence, purchase flow, paid gate, SwiftData schema, workflow behavior, Mac Catalyst, or real StoreKit validation is changed.
- Completed: Refined the Plan Availability Purchase UI detail so it states Purchase UI remains hidden until StoreKit products and entitlement mapping exist.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.80 version.
- Risk: This is Plan Availability purchase UI copy only; no StoreKit products, purchase UI, entitlement persistence, purchase flow, paid gate, SwiftData schema, workflow behavior, Mac Catalyst, or real Mac validation is changed.
- Completed: Refined the Mac Readiness Distribution and signing detail so it states Mac release channel, signing, sandboxing, and notarization still need a product decision.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.79 version.
- Risk: This is Plan Mac readiness distribution/signing copy only; no Mac Catalyst, Xcode project, signing configuration, notarization, distribution setup, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Mac Readiness Native backend slice detail so it states the native inference framework still needs a Mac or Catalyst slice before Mac builds can run.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.78 version.
- Risk: This is Plan Mac readiness native backend copy only; no Mac Catalyst, Xcode project, native backend slice, Plan data structure, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Refined the Mac Readiness Apple platform support detail so it states this build is still configured for the iPhone and iPad app target only.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.77 version.
- Risk: This is Plan Mac readiness detail copy only; no Mac Catalyst, Xcode project, native backend slice, Plan data structure, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Renamed the Mac Readiness platform row from Xcode target platform to Apple platform support.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.76 version.
- Risk: This is Plan Mac readiness title copy only; no Mac Catalyst, Xcode project, native backend slice, Plan data structure, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Replaced the Mac Readiness window/sidebar user-visible testing term with QA validation wording.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.75 version.
- Risk: This is Plan Mac readiness QA copy only; no Mac Catalyst, Xcode project, native backend slice, Plan data structure, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Added contextual footer note semantics to the compact and iPad regular Plan Availability section.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.74 version.
- Risk: This is Plan Availability footer context only; no Availability row data, StoreKit, entitlement persistence, purchase flow, Mac Catalyst, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Renamed the Mac Readiness window/sidebar validation status from Planned to Needs QA.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.73 version.
- Risk: This is Plan Mac readiness status copy only; no Mac Catalyst, Xcode project, native backend slice, Plan data structure, StoreKit, entitlement persistence, purchase flow, SwiftData schema, workflow behavior, or real Mac validation is changed.
- Completed: Added contextual VoiceOver note labels and values to compact Plan section footers for Mac Readiness, Capability Matrix, and Entitlement Rules.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.72 version.
- Risk: This is Plan compact footer accessibility semantics only; no visible footer text, Form/Section structure, Plan data, StoreKit, entitlement persistence, purchase flow, Mac Catalyst, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Clarified the iPad sidebar Plan hint so it names local plan, planning-only paid capability status, and platform readiness.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.71 version.
- Risk: This is Root sidebar accessibility copy only; no visible UI, TabView/sidebar structure, navigation state, Plan copy, StoreKit, entitlement persistence, purchase flow, Mac Catalyst, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Replaced the Root Plan navigation payment-coded icon with a neutral planning/checklist icon for compact tabs and iPad sidebar.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.70 version.
- Risk: This is Root navigation visual semantics only; no TabView/sidebar structure, navigation state, Plan copy, StoreKit, entitlement persistence, purchase flow, Mac Catalyst, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Replaced the Plan overview payment-coded icon with a neutral planning/checklist visual signal.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.69 version.
- Risk: This is Plan overview visual semantics only; no Plan navigation icon, TabView/sidebar behavior, Plan copy, StoreKit, entitlement persistence, purchase flow, Mac Catalyst, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Generate model Picker VoiceOver label/value/hint semantics for the current selected model and ready model count.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.68 version.
- Risk: This is Generate model picker semantics only; no model query, model selection binding, generation gate, navigation behavior, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Generate Model section no-model Open Models VoiceOver value/hint semantics and a 44pt minimum hit area.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.67 version.
- Risk: This is Generate empty model entry semantics only; no model query, model selection, generation gate, navigation behavior, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Models untracked GGUF import editor toolbar Import/Cancel VoiceOver semantics for ready/display-name-required states and close-without-importing context.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.66 version.
- Risk: This is Models untracked import editor toolbar semantics only; no untracked file scan, import behavior, delete behavior, download state machine, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Gallery folder editor toolbar Save/Cancel VoiceOver semantics for ready/name-required states and close-without-saving context.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.65 version.
- Risk: This is Gallery folder editor toolbar semantics only; no folder create, rename, delete, filter, sort, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Gallery detail action VoiceOver context for Reuse Parameters, Reuse and Generate, Share PNG, and Delete Image actions.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.64 version.
- Risk: This is Gallery detail action semantics only; no reuse, regenerate, share, delete, file storage, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Prompt editor and category rename toolbar Save/Cancel VoiceOver semantics for ready/name-required states and close-without-saving context.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.63 version.
- Risk: This is Prompt Library editor toolbar semantics only; no template save, rename, search, load, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Generate run action VoiceOver value and hint semantics for ready/blocked states, plus next-step context for Open Models and Edit Prompt in the Run section.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.62 version.
- Risk: This is Generate Run section semantics only; no generation gate, generation/cancel behavior, navigation behavior, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Generate Save Template toolbar VoiceOver value and hint semantics for ready and positive-prompt-required states.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.61 version.
- Risk: This is Generate toolbar semantics only; no template save fields, PromptTemplate schema, generation flow, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Models toolbar Refresh Storage and Add menu VoiceOver context, including import readiness and menu action hints.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.60 version.
- Risk: This is Models toolbar semantics only; no download, import, refresh, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Gallery folder rename/delete action VoiceOver context for swipe actions and context menus while preserving folder action behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.59 version.
- Risk: This is Gallery folder action semantics only; no folder filter, rename/delete behavior, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Prompt Library search field submit semantics and a VoiceOver hint that explains template name, category, positive prompt, and negative prompt matching.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.58 version.
- Risk: This is Prompt Library search field semantics only; no search algorithm, template mutation, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Plan summary row VoiceOver hints that clarify Local plan, StoreKit products not configured, iPhone/iPad availability, and Mac Catalyst not enabled.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.57 version.
- Risk: This is Plan Current Build and Platform Status summary semantics only; no StoreKit product, purchase UI, entitlement persistence, Mac Catalyst, native backend, SwiftData schema, Xcode project, or workflow behavior is changed.
- Completed: Added Plan Entitlement Rules row VoiceOver hints that clarify protected local tools, planning-only paid candidates, StoreKit purchase prerequisites, and missing entitlement persistence.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.56 version.
- Risk: This is Plan Entitlement Rules row semantics only; no StoreKit product, purchase UI, entitlement persistence, paid gate, Mac Catalyst, native backend, SwiftData schema, Xcode project, or workflow behavior is changed.
- Completed: Added Plan Capability Matrix row VoiceOver hints that clarify current Local plan availability, planning-only paid candidates, and StoreKit configuration prerequisites.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.55 version.
- Risk: This is Plan Capability Matrix row semantics only; no StoreKit product, purchase UI, entitlement persistence, paid gate, Mac Catalyst, native backend, SwiftData schema, Xcode project, or workflow behavior is changed.
- Completed: Added Plan Mac readiness row VoiceOver hints that clarify target-platform, native backend slice, Mac UI QA, and signing/distribution blockers.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.54 version.
- Risk: This is Plan Mac readiness row semantics only; no Mac Catalyst, Xcode project, signing, StoreKit product, purchase UI, entitlement persistence, native backend, SwiftData schema, or workflow behavior is changed.
- Completed: Added Plan Availability row VoiceOver hints that clarify Local tools availability, paid candidates planning-only status, Purchase UI prerequisites, and Mac app not-enabled status.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.53 version.
- Risk: This is Plan Availability row semantics only; no StoreKit product, purchase UI, restore, receipt, subscription, entitlement persistence, paid gate, Mac Catalyst, Xcode project, native backend, SwiftData schema, or workflow behavior is changed.
- Completed: Added Prompt template metric pill VoiceOver semantics that identify saved steps, sampler algorithm, and canvas pixel size.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.52 version.
- Risk: This is Prompt template row metric semantics only; no template search, grouping, sorting, add, edit, delete, load, parameter persistence, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Models empty-state VoiceOver semantics that expose no tracked models, no untracked GGUF files, and the download/import next steps.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.51 version.
- Risk: This is Models empty-state semantics only; no download, import, untracked file scan, delete, detail sheet, storage reconcile, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added Gallery empty-state VoiceOver semantics that expose the active filter and zero-image count when the visible image grid is empty.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.50 version.
- Risk: This is Gallery empty-state semantics only; no filter, sort, folder/tag mutation, navigation, delete, share, reuse, regenerate, reconcile, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.

### 2026-07-05

- Completed: Added shared Seed text field VoiceOver hint semantics that explain the field edits the seed value for the current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.49 version.
- Risk: This is shared ParameterEditor text field semantics only; no seed default, type, random range, input behavior, randomize behavior, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Width and Height stepper VoiceOver hint semantics that explain the controls adjust canvas pixel dimensions for the current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.48 version.
- Risk: This is shared ParameterEditor stepper semantics only; no dimension range, step, binding, normalization, size preset behavior, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared CFG slider VoiceOver hint semantics that explain the control adjusts prompt guidance strength for the current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.47 version.
- Risk: This is shared ParameterEditor slider semantics only; no CFG range, step, default value, binding, normalization, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Steps stepper VoiceOver hint semantics that explain the control adjusts denoising steps for the current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.46 version.
- Risk: This is shared ParameterEditor stepper semantics only; no steps range, default value, binding, normalization, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Sampler picker VoiceOver hint semantics that explain the picker chooses the sampling algorithm for the current generation parameters.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.45 version.
- Risk: This is shared ParameterEditor picker semantics only; no sampler options, raw values, binding, normalization, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Canvas Size preset VoiceOver hint semantics that explain presets update width and height while custom dimensions remain editable.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.44 version.
- Risk: This is shared ParameterEditor menu semantics only; no size preset list, width/height assignment, dimension normalization, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Randomize Seed VoiceOver value and hint semantics that expose the current seed and explain that the control generates a new random seed.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.43 version.
- Risk: This is shared ParameterEditor button semantics only; no seed randomization range, seed field behavior, parameter defaults, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added shared Reset Defaults VoiceOver semantics that explain parameter reset scope while preserving positive and negative prompts.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.42 version.
- Risk: This is shared ParameterEditor button semantics only; no parameter defaults, reset behavior, template behavior, generation behavior, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added current-sort VoiceOver value semantics to the Gallery Sort menu while preserving existing newest, oldest, and model sorting behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.41 version.
- Risk: This is Gallery Sort menu semantics only; no sorting algorithm, filtering, detail navigation, deletion, sharing, reuse, regeneration, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added template-name VoiceOver context to Prompt template row edit/load controls while preserving existing edit and load behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.40 version.
- Risk: This is Prompt template row control semantics only; no template query, search, grouping, sorting, edit, load, delete, category mutation, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added model-name VoiceOver context to Models row inline controls while preserving existing details, download, pause, cancel, resume, and delete behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.39 version.
- Risk: This is Models row control semantics only; no download state machine, file storage, import, delete confirmation, SwiftData schema, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added an iPad pointer hover affordance and category-aware VoiceOver context baseline for Prompt Library category action menus while preserving rename and clear behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.38 version.
- Risk: This is Prompt Library category menu UI semantics only; no template query, search, grouping, sorting, edit, load, delete, category mutation, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added an iPad pointer hover affordance baseline for Gallery filter rail rows while preserving existing filter selection, tags, counts, and accessibility summaries.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.37 version.
- Risk: This is Gallery filter rail UI affordance only; no Gallery filtering, sorting, detail navigation, deletion, sharing, reuse, regeneration, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Aligned the Plan Capability Matrix paid candidate status and details with the existing planning-only Availability and Entitlement Rules language, making clear that Batch queue controls, curated prompt packs, and workflow export are not sold or unlocked.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.36 version.
- Risk: This is Plan copy/status semantics only; no StoreKit product, purchase flow, restore, receipt, subscription, entitlement persistence, paid gate, Mac Catalyst support, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added an iPad pointer hover affordance baseline for Gallery image tiles while preserving existing tile navigation, plain button styling, and accessibility summaries.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.35 version.
- Risk: This is Gallery UI affordance only; no Gallery filtering, sorting, detail navigation, deletion, sharing, reuse, regeneration, SwiftData schema, file storage, StoreKit, Mac Catalyst, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added an iPad pointer hover affordance baseline for regular-width sidebar rows and shared Sci-Fi primary/secondary buttons.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.34 version.
- Risk: This is iPad UI affordance only; no Mac Catalyst support, Mac build validation, StoreKit product, purchase flow, entitlement persistence, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added a Plan Availability row for paid candidates and renamed the paid candidate entitlement status to Planning only, making clear that Batch queue, curated prompt packs, and workflow export are not sold or unlocked in this build.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.33 version.
- Risk: This is presentation-only; no StoreKit product, purchase flow, restore, receipt, subscription, entitlement persistence, paid gate, Mac Catalyst support, SwiftData schema, native backend, Xcode project, or workflow behavior is changed.
- Completed: Added a Plan Availability row for Mac app status, explicitly showing that no Mac or Catalyst app ships from the current iOS target while Mac support still needs platform, native backend, signing, and UI validation work.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.32 version.
- Risk: This is presentation-only; no Mac Catalyst support, Xcode platform setting, native Mac/Catalyst slice, StoreKit purchase flow, entitlement persistence, SwiftData schema, or workflow behavior is changed.
- Completed: Refined Plan iPad regular panels so custom panel titles expose heading semantics and panel footers expose contextual note labels for VoiceOver navigation.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.31 version.
- Risk: This is presentation-only; no Plan facts, StoreKit purchase flow, entitlement persistence, Mac Catalyst support, native backend, Xcode project, SwiftData schema, or workflow behavior is changed.
- Completed: Refined Gallery detail organization controls so VoiceOver receives current folder assignment, tag input, and Save Tags change state without changing folder or tag save behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.30 version.
- Risk: This is presentation-only; no folder binding, tag parsing, tag saving, SwiftData schema, file storage, delete/share/reuse/regenerate behavior, native backend, StoreKit, Mac Catalyst, or workflow behavior is changed.
- Completed: Refined Generate run status semantics so VoiceOver receives combined readiness, progress percentage, cancel state, generated preview dimensions, and Gallery handoff state.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.29 version.
- Risk: This is presentation-only; no generation gate condition, generation start, cancel, save, Gallery navigation, SwiftData schema, native backend, StoreKit, Mac Catalyst, or workflow behavior is changed.
- Completed: Refined Prompt Library empty states so VoiceOver receives a combined no-template or no-search-result status with the current search context and next-step hints.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.28 version.
- Risk: This is presentation-only; no template query, search filtering, add/edit/delete/load behavior, SwiftData schema, native backend, StoreKit, Mac Catalyst, or workflow behavior is changed.
- Completed: Refined untracked model file rows so file name/size and Import/Delete actions expose file-specific VoiceOver context while preserving import and delete behavior.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.27 version.
- Risk: This is presentation-only; no untracked file scan, import, delete confirmation, file storage, SwiftData schema, native backend, or data-layer behavior is changed.
- Completed: Refined Add Model keyboard submission so Return can parse a pasted Hugging Face URL or submit completed model fields, while the Download button exposes ready/missing VoiceOver status.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.26 version.
- Risk: This is presentation/input-semantics only; no URL parsing, duplicate detection, file storage, SwiftData schema, download creation, native backend, or data-layer behavior is changed.
- Completed: Refined the Models storage summary so VoiceOver receives one combined ready/tracked/on-disk/untracked summary while the visible Storage Matrix layout stays unchanged.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.25 version.
- Risk: This is presentation-only; no storage statistics, file scanning, import, delete, download, SwiftData schema, native backend, or data-layer behavior is changed.
- Completed: Refined Add Model errors so invalid Hugging Face sources, duplicate models, and local file conflicts use readable 44pt rows with explicit VoiceOver label/value/hint semantics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.24 version.
- Risk: This is presentation-only; no URL parsing, duplicate detection, file storage, SwiftData schema, download creation, native backend, or data-layer behavior is changed.
- Completed: Refined Models detail status messages so the model detail sheet keeps download and storage messages readable, wrapped, and exposed with explicit VoiceOver label/value/hint semantics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.23 version.
- Risk: This is presentation-only; no download state machine, file storage, SwiftData schema, native backend, navigation, native loading, or data-layer behavior is changed.
- Completed: Refined Models row status messages so download and storage messages keep readable 44pt rows, wrap at Dynamic Type sizes, and expose explicit VoiceOver label/value/hint semantics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.22 version.
- Risk: This is presentation-only; no download state machine, file storage, SwiftData schema, native backend, navigation, or data-layer behavior is changed.
- Completed: Refined Plan note rows so StoreKit-disabled and Mac-support prerequisite notes keep readable 44pt rows, wrap at Dynamic Type sizes, and expose explicit VoiceOver label/value/hint semantics.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.21 version.
- Risk: This is presentation-only; no StoreKit purchase flow, entitlement persistence, Mac Catalyst support, native backend, navigation, or data-layer behavior is changed.
- Completed: Refined iPad sidebar rows so each main navigation section keeps a readable 44pt row and exposes explicit selected/not-selected VoiceOver values and workspace hints.
- Verified: Local lightweight checks, Swift parse, iPhoneOS build, and cloud CI artifact review are required for the v1.20 version.
- Risk: This is presentation-only; no Root navigation state, TabView, Gallery layout, StoreKit, Mac Catalyst, native backend, or data-layer behavior is changed.
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
