#ifndef NativeStableDiffusionBridge_h
#define NativeStableDiffusionBridge_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    const char *model_path;
    const char *diffusion_model_path;
    const char *clip_l_path;
    const char *clip_g_path;
    const char *t5xxl_path;
    const char *vae_path;
    const char *prompt;
    const char *negative_prompt;
    int32_t steps;
    float cfg_scale;
    int64_t seed;
    int32_t width;
    int32_t height;
    const char *sampler;
} LDIImageGenerationInput;

typedef bool (*LDIProgressCallback)(float fraction, const char *stage, void *context);

typedef struct {
    uint8_t *bytes;
    int64_t count;
    const char *error_message;
} LDIImageResult;

int32_t ldi_sd_generate_png(
    const LDIImageGenerationInput *input,
    LDIProgressCallback progress,
    void *context,
    LDIImageResult *result
);

void ldi_sd_free_result(LDIImageResult *result);

#ifdef __cplusplus
}
#endif

#endif
