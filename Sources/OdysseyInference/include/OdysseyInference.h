#ifndef ODYSSEY_INFERENCE_H
#define ODYSSEY_INFERENCE_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct OdysseyLandmarkModel OdysseyLandmarkModel;
OdysseyLandmarkModel *odyssey_landmark_create(const char *path, int *status);
void odyssey_landmark_destroy(OdysseyLandmarkModel *model);
// Accepts exactly 192x192 grayscale float samples. Output: 198 XY pairs + logit.
// Returns 0 on success; -1 for an invalid model/input, or a LiteRT error code.
int odyssey_landmark_invoke(OdysseyLandmarkModel *model, const float *input, size_t input_count,
                            float *coordinates, size_t output_count, float *logit);
typedef struct OdysseyFaceModel OdysseyFaceModel;
OdysseyFaceModel *odyssey_face_create(const char *path, int *status);
void odyssey_face_destroy(OdysseyFaceModel *model);
// Gray NCHW input 1x1x320x448. Concatenated outputs: 48x40x56,
// 48x20x28, 48x10x14. Caller serializes use of each model instance.
int odyssey_face_invoke(OdysseyFaceModel *model, const float *input, size_t input_count,
                        float *output, size_t output_count);
typedef struct OdysseyDepthModel OdysseyDepthModel;
OdysseyDepthModel *odyssey_depth_create(const char *path, int *status);
void odyssey_depth_destroy(OdysseyDepthModel *model);
int odyssey_depth_invoke(OdysseyDepthModel *model, const float *input, size_t input_count,
                         float *output, size_t output_count);
#ifdef __cplusplus
}
#endif
#endif
