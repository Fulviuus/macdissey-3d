#ifndef ODYSSEY_VISION_H
#define ODYSSEY_VISION_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
// Input arrays: 68x3 model coordinates, 68x2 image pixels, a subset of 6..68
// indices, 3x3 camera matrix, and 8 distortion coefficients. Output is camera
// translation followed by Rodrigues rotation (or Euler angles when requested).
// Returns 0 on success, 1 for invalid input, 2 for a failed pose solve.
int odyssey_solve_pose(const double *model, const double *pixels, const int32_t *subset,
                       size_t subset_count, const double *camera, const double *distortion,
                       double image_width, double ratio, int euler, double *output);
// Default Blink landmark crop: 192x192 grayscale float, replicated borders,
// original perspective mapping and aspect expansion. Region is cx,cy,w,h,angle.
int odyssey_landmark_crop(const uint8_t *pixels, size_t byte_count, int width, int height,
                          size_t stride, const float *region, float *tensor, size_t tensor_count,
                          float *adjusted_region);
// ET/LRGB calibrated phase attributes. p is slant,pitch,d_cm,d_pixels,n,
// phase*28,pattern(0),pixel_cm. Eye is the driver's predicted midpoint in cm.
// Output is phase[4],dxy[4],screen[2],weave[2].
void odyssey_weave_attributes(const float *p, const float *eye, const float *resolution,
                              const float *offset, const float *vertex, float *output);
// Original grayscale face preprocessing. Padding order is left,right,top,bottom.
int odyssey_face_letterbox(const uint8_t *pixels, size_t byte_count, int width, int height,
                           size_t stride, float *tensor, size_t tensor_count, int32_t *padding);
// Original YOLOv5 outputs, concatenated as the face inference API returns them.
// Detections are 20 floats: XYWH, five XYZ keypoints, confidence.
int odyssey_face_decode(const float *tensor, size_t tensor_count, const int32_t *padding,
                        float confidence_threshold, float nms_threshold, float *detections,
                        size_t capacity, size_t *count);
int odyssey_face_clahe(const uint8_t *pixels, size_t byte_count, int width, int height,
                       size_t stride, uint8_t *output, size_t output_count);
typedef struct OdysseyDepthPreparation OdysseyDepthPreparation;
// Immutable calibration/map ownership; calls on one instance must be serialized.
OdysseyDepthPreparation *odyssey_depth_preparation_create(int width, int height,
                                                          const double *camera,
                                                          const double *distortion, int *status);
void odyssey_depth_preparation_destroy(OdysseyDepthPreparation *preparation);
// Rectangle is pixel XYWH. Geometry: corrected XYWH, scaled WH, crop XY.
int odyssey_depth_prepare(OdysseyDepthPreparation *preparation, const uint8_t *pixels,
                          size_t byte_count, int channels, size_t stride, const double *rectangle,
                          float *tensor, size_t tensor_count, int32_t *geometry);
// Copy most recent undistorted(0), scaled(1), or cropped(2) bytes for verification.
int odyssey_depth_preparation_stage(OdysseyDepthPreparation *preparation, int stage, uint8_t *bytes,
                                    size_t capacity, size_t *count);
// Original SREyeTracker stereo triangulation. Pixel pairs are float left XY,
// right XY; matrix inputs are row-major doubles. Output XYZ remains float.
int odyssey_stereo_triangulate(const double *left_camera, const double *left_distortion,
                               const double *right_camera, const double *right_distortion,
                               const double *rotation, const double *translation,
                               const float *pixels, double minimum_depth, double maximum_error,
                               float *point, double *reprojection_error, int *accepted);
// Camera histories contain eye0 XY then eye1 XY for each timestamp. Output is
// eye0 XY in each camera followed by eye1 XY in each camera (eight floats).
int odyssey_stereo_fit(const double *timestamps, const float *left, const float *right,
                       size_t count, int order, float *output);
#ifdef __cplusplus
}
#endif
#endif
