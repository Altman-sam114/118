# StableDiffusionCpp Native Backend

This folder contains the Objective-C++ implementation for the C ABI declared in `LocalDiffusion/Inference/NativeStableDiffusionBridge.h`.

It is intentionally not part of the Swift app target. The build script compiles it beside `stable-diffusion.cpp`, packages the result as a static XCFramework, and links that XCFramework into `LocalDiffusion`.

## Expected flow

1. Check out `stable-diffusion.cpp`.
2. Run:

   ```bash
   ./Scripts/install-native-backend.sh /path/to/stable-diffusion.cpp
   ```

3. Run `./Scripts/check-native-backend.sh`.

`install-native-backend.sh` builds `LocalDiffusionNative.xcframework`, installs it under `LocalDiffusion/Frameworks`, links it in the Xcode target's Frameworks phase, and assigns `LocalDiffusion/Config/NativeBackend.xcconfig` so Swift compiles with `USE_STABLE_DIFFUSION_CPP`.

## Release asset metadata

CI restores `LocalDiffusionNative.xcframework.zip` from the GitHub Release tag `native-backend-current`. The expected asset name and SHA-256 digest are tracked in `native-backend-asset.json`.

When the XCFramework zip is rebuilt or replaced, refresh `native-backend-asset.json` in the same change as the Release asset update. CI downloads the asset, checks its SHA-256 before unzip, writes `ci-results/native-backend-asset.log`, and skips native preflight/build if the digest does not match.

The generated static library exports:
   - `ldi_sd_generate_png`
   - `ldi_sd_free_result`

The bridge maps Swift generation parameters to the current `stable-diffusion.cpp` C API:

- `sd_ctx_params_init(&params)` and `new_sd_ctx(&params)` load the local model file.
- `sd_sample_params_init(&params)` configures sampler, scheduler, CFG, and steps.
- `sd_img_gen_params_init(&params)` configures prompt, negative prompt, seed, size, and batch count.
- `generate_image(ctx, &params)` returns raw image pixels, which the bridge encodes as PNG bytes for Swift.

`stable-diffusion.cpp` changes frequently. If the upstream header changes, adjust only this native bridge and keep the Swift UI/backend protocol unchanged.
