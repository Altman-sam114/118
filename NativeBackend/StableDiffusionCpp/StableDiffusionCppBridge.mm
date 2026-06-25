#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "../../LocalDiffusion/Inference/NativeStableDiffusionBridge.h"

// Compile this file inside the native XCFramework target that also builds and
// links stable-diffusion.cpp. The Swift app target intentionally does not
// compile this file directly.
#include "stable-diffusion.h"

namespace {

std::mutex g_generation_mutex;

struct ProgressState {
    LDIProgressCallback callback;
    void *context;
    std::atomic_bool cancellation_requested;
};

struct ProgressCallbackScope {
    ProgressState *state;

    explicit ProgressCallbackScope(ProgressState *state) : state(state) {
        sd_set_progress_callback(stable_diffusion_progress, state);
    }

    ~ProgressCallbackScope() {
        sd_set_progress_callback(nullptr, nullptr);
    }

    static void stable_diffusion_progress(int step, int steps, float, void *data) {
        ProgressState *state = static_cast<ProgressState *>(data);
        if (!state || !state->callback) {
            return;
        }

        const int safe_steps = std::max(steps, 1);
        const float fraction = std::clamp(static_cast<float>(step) / static_cast<float>(safe_steps), 0.0f, 1.0f);
        const std::string stage = "Step " + std::to_string(step) + " of " + std::to_string(safe_steps);
        const bool should_continue = state->callback(fraction, stage.c_str(), state->context);
        if (!should_continue) {
            state->cancellation_requested.store(true);
        }
    }
};

char *copy_c_string(const std::string &value) {
    char *copy = static_cast<char *>(std::malloc(value.size() + 1));
    if (!copy) {
        return nullptr;
    }
    std::memcpy(copy, value.c_str(), value.size() + 1);
    return copy;
}

void set_error(LDIImageResult *result, const std::string &message) {
    if (result) {
        result->error_message = copy_c_string(message);
    }
}

void emit_progress(LDIProgressCallback progress, void *context, float fraction, const char *stage) {
    if (progress) {
        progress(std::clamp(fraction, 0.0f, 1.0f), stage, context);
    }
}

std::string normalized_sampler_name(const char *value) {
    if (!value) {
        return "";
    }

    std::string sampler(value);
    std::transform(sampler.begin(), sampler.end(), sampler.begin(), [](unsigned char character) {
        return static_cast<char>(std::tolower(character));
    });
    return sampler;
}

sample_method_t sample_method_from_string(const sd_ctx_t *context, const char *value) {
    if (value && std::strlen(value) > 0) {
        const sample_method_t parsed = str_to_sample_method(value);
        if (parsed != SAMPLE_METHOD_COUNT) {
            return parsed;
        }
    }

    const std::string sampler = normalized_sampler_name(value);
    if (sampler.find("euler a") != std::string::npos) {
        return EULER_A_SAMPLE_METHOD;
    }
    if (sampler.find("euler") != std::string::npos) {
        return EULER_SAMPLE_METHOD;
    }
    if (sampler.find("heun") != std::string::npos) {
        return HEUN_SAMPLE_METHOD;
    }
    if (sampler.find("dpm2") != std::string::npos) {
        return DPM2_SAMPLE_METHOD;
    }
    if (sampler.find("2s") != std::string::npos) {
        return DPMPP2S_A_SAMPLE_METHOD;
    }
    if (sampler.find("2m v2") != std::string::npos || sampler.find("2mv2") != std::string::npos) {
        return DPMPP2Mv2_SAMPLE_METHOD;
    }
    if (sampler.find("2m") != std::string::npos) {
        return DPMPP2M_SAMPLE_METHOD;
    }
    if (sampler.find("sde") != std::string::npos) {
        return ER_SDE_SAMPLE_METHOD;
    }
    if (sampler.find("lcm") != std::string::npos) {
        return LCM_SAMPLE_METHOD;
    }

    return sd_get_default_sample_method(context);
}

int safe_dimension(int32_t value, int fallback) {
    if (value < 64 || value > 2048) {
        return fallback;
    }
    return static_cast<int>(value);
}

int safe_steps(int32_t value) {
    return std::max(1, std::min(static_cast<int>(value), 150));
}

bool encode_png_rgba(const uint8_t *rgba, int width, int height, std::vector<uint8_t> *png) {
    if (!rgba || width <= 0 || height <= 0 || !png) {
        return false;
    }

    CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
    if (!color_space) {
        return false;
    }

    const size_t bytes_per_row = static_cast<size_t>(width) * 4;
    CGDataProviderRef provider = CGDataProviderCreateWithData(
        nullptr,
        rgba,
        bytes_per_row * static_cast<size_t>(height),
        nullptr
    );
    if (!provider) {
        CGColorSpaceRelease(color_space);
        return false;
    }

    CGImageRef image = CGImageCreate(
        static_cast<size_t>(width),
        static_cast<size_t>(height),
        8,
        32,
        bytes_per_row,
        color_space,
        kCGImageAlphaLast | kCGBitmapByteOrder32Big,
        provider,
        nullptr,
        false,
        kCGRenderingIntentDefault
    );

    CGDataProviderRelease(provider);
    CGColorSpaceRelease(color_space);

    if (!image) {
        return false;
    }

    NSMutableData *data = [NSMutableData data];
    CFStringRef type_identifier = (__bridge CFStringRef)UTTypePNG.identifier;
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)data,
        type_identifier,
        1,
        nullptr
    );
    if (!destination) {
        CGImageRelease(image);
        return false;
    }

    CGImageDestinationAddImage(destination, image, nullptr);
    const bool finalized = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);

    if (!finalized || data.length == 0) {
        return false;
    }

    const uint8_t *bytes = static_cast<const uint8_t *>(data.bytes);
    png->assign(bytes, bytes + data.length);
    return true;
}

std::vector<uint8_t> image_to_rgba(const sd_image_t &image) {
    const int width = static_cast<int>(image.width);
    const int height = static_cast<int>(image.height);
    const int channels = static_cast<int>(image.channel);
    const size_t pixel_count = static_cast<size_t>(width) * static_cast<size_t>(height);
    std::vector<uint8_t> rgba(pixel_count * 4, 255);

    if (!image.data || width <= 0 || height <= 0 || channels <= 0) {
        return {};
    }

    for (size_t index = 0; index < pixel_count; ++index) {
        const size_t source = index * static_cast<size_t>(channels);
        const size_t target = index * 4;

        if (channels == 1) {
            rgba[target] = image.data[source];
            rgba[target + 1] = image.data[source];
            rgba[target + 2] = image.data[source];
        } else if (channels == 2) {
            rgba[target] = image.data[source];
            rgba[target + 1] = image.data[source];
            rgba[target + 2] = image.data[source];
            rgba[target + 3] = image.data[source + 1];
        } else {
            rgba[target] = image.data[source];
            rgba[target + 1] = image.data[source + 1];
            rgba[target + 2] = image.data[source + 2];
            rgba[target + 3] = channels >= 4 ? image.data[source + 3] : 255;
        }
    }

    return rgba;
}

void free_generated_images(sd_image_t *images, int count) {
    if (!images) {
        return;
    }

    for (int index = 0; index < count; ++index) {
        std::free(images[index].data);
        images[index].data = nullptr;
    }
    std::free(images);
}

} // namespace

extern "C" int32_t ldi_sd_generate_png(
    const LDIImageGenerationInput *input,
    LDIProgressCallback progress,
    void *context,
    LDIImageResult *result
) {
    if (!result) {
        return -1;
    }

    result->bytes = nullptr;
    result->count = 0;
    result->error_message = nullptr;

    if (!input || (!input->model_path && !input->diffusion_model_path) || !input->prompt) {
        set_error(result, "Missing model path or prompt.");
        return -2;
    }

    std::lock_guard<std::mutex> generation_lock(g_generation_mutex);

    ProgressState progress_state = {
        progress,
        context,
        false
    };
    ProgressCallbackScope progress_scope(&progress_state);

    emit_progress(progress, context, 0.01f, "Loading model");

    sd_ctx_params_t ctx_params;
    sd_ctx_params_init(&ctx_params);
    ctx_params.model_path = input->model_path;
    ctx_params.diffusion_model_path = input->diffusion_model_path;
    ctx_params.clip_l_path = input->clip_l_path;
    ctx_params.clip_g_path = input->clip_g_path;
    ctx_params.t5xxl_path = input->t5xxl_path;
    ctx_params.vae_path = input->vae_path;
    ctx_params.n_threads = std::max(1, sd_get_num_physical_cores());
    ctx_params.rng_type = CPU_RNG;
    ctx_params.sampler_rng_type = CPU_RNG;
    ctx_params.vae_decode_only = true;
    ctx_params.free_params_immediately = true;
    ctx_params.enable_mmap = true;

    std::unique_ptr<sd_ctx_t, decltype(&free_sd_ctx)> sd_context(new_sd_ctx(&ctx_params), free_sd_ctx);
    if (!sd_context) {
        set_error(result, "Failed to create stable-diffusion.cpp context.");
        return -3;
    }

    if (!sd_ctx_supports_image_generation(sd_context.get())) {
        set_error(result, "The selected stable-diffusion.cpp context does not support image generation.");
        return -4;
    }

    const int width = safe_dimension(input->width, 512);
    const int height = safe_dimension(input->height, 512);
    const int steps = safe_steps(input->steps);

    sd_sample_params_t sample_params;
    sd_sample_params_init(&sample_params);
    sample_params.sample_method = sample_method_from_string(sd_context.get(), input->sampler);
    sample_params.scheduler = sd_get_default_scheduler(sd_context.get(), sample_params.sample_method);
    sample_params.sample_steps = steps;
    sample_params.guidance.txt_cfg = input->cfg_scale > 0 ? input->cfg_scale : 7.0f;

    sd_img_gen_params_t image_params;
    sd_img_gen_params_init(&image_params);
    image_params.prompt = input->prompt;
    image_params.negative_prompt = input->negative_prompt ? input->negative_prompt : "";
    image_params.width = width;
    image_params.height = height;
    image_params.seed = input->seed;
    image_params.sample_params = sample_params;
    image_params.batch_count = 1;
    image_params.vae_tiling_params.enabled = true;

    emit_progress(progress, context, 0.03f, "Sampling");
    sd_image_t *images = generate_image(sd_context.get(), &image_params);
    const int image_count = std::max(image_params.batch_count, 1);

    if (progress_state.cancellation_requested.load()) {
        free_generated_images(images, image_count);
        set_error(result, "Generation cancelled.");
        return -5;
    }

    if (!images || !images[0].data) {
        free_generated_images(images, image_count);
        set_error(result, "stable-diffusion.cpp returned no image data.");
        return -6;
    }

    emit_progress(progress, context, 0.97f, "Encoding PNG");

    std::vector<uint8_t> rgba = image_to_rgba(images[0]);
    std::vector<uint8_t> png;
    const bool encoded = !rgba.empty()
        && encode_png_rgba(
            rgba.data(),
            static_cast<int>(images[0].width),
            static_cast<int>(images[0].height),
            &png
        );
    free_generated_images(images, image_count);

    if (!encoded || png.empty()) {
        set_error(result, "Failed to encode generated image as PNG.");
        return -7;
    }

    uint8_t *bytes = static_cast<uint8_t *>(std::malloc(png.size()));
    if (!bytes) {
        set_error(result, "Unable to allocate PNG result buffer.");
        return -8;
    }

    std::memcpy(bytes, png.data(), png.size());
    result->bytes = bytes;
    result->count = static_cast<int64_t>(png.size());

    emit_progress(progress, context, 1.0f, "Complete");
    return 0;
}

extern "C" void ldi_sd_free_result(LDIImageResult *result) {
    if (!result) {
        return;
    }

    std::free(result->bytes);
    result->bytes = nullptr;
    result->count = 0;

    std::free(const_cast<char *>(result->error_message));
    result->error_message = nullptr;
}
