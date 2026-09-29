#include "OdysseyVision.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
#include <memory>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>

struct OdysseyDepthPreparation {
  int width, height;
  float scale;
  cv::Mat camera, distortion, mapX, mapY, undistorted, scaled, crop;
};
OdysseyDepthPreparation *odyssey_depth_preparation_create(int width, int height,
                                                          const double *camera,
                                                          const double *distortion, int *status) {
  if (!status)
    return nullptr;
  *status = 1;
  if (!camera || !distortion || width < 1 || height < 1 || width > 8192 || height > 8192)
    return nullptr;
  for (int i = 0; i < 9; i++)
    if (!std::isfinite(camera[i]))
      return nullptr;
  for (int i = 0; i < 8; i++)
    if (!std::isfinite(distortion[i]))
      return nullptr;
  if (camera[0] <= 0 || camera[4] <= 0)
    return nullptr;
  const float scale = 1280.0f / (float)camera[0];
  if (!std::isfinite(scale) || width * (double)scale < 1 || height * (double)scale < 1 ||
      width * (double)scale > 8192 || height * (double)scale > 8192)
    return nullptr;
  try {
    std::unique_ptr<OdysseyDepthPreparation> result(new OdysseyDepthPreparation());
    result->width = width;
    result->height = height;
    result->scale = scale;
    result->camera = cv::Mat(3, 3, CV_64F, const_cast<double *>(camera)).clone();
    result->camera.at<double>(0, 2) = width - camera[2];
    result->distortion = cv::Mat(1, 8, CV_64F, const_cast<double *>(distortion)).clone();
    cv::initUndistortRectifyMap(result->camera, result->distortion, cv::Mat(), result->camera,
                                cv::Size(width, height), CV_32FC1, result->mapX, result->mapY);
    *status = 0;
    return result.release();
  } catch (...) {
    *status = 2;
    return nullptr;
  }
}
void odyssey_depth_preparation_destroy(OdysseyDepthPreparation *preparation) { delete preparation; }
int odyssey_depth_prepare(OdysseyDepthPreparation *p, const uint8_t *pixels, size_t byte_count,
                          int channels, size_t stride, const double *rectangle, float *tensor,
                          size_t tensor_count, int32_t *geometry) {
  if (!p || !pixels || !rectangle || !tensor || !geometry || (channels != 1 && channels != 3) ||
      tensor_count != 3 * 224 * 224 || stride < (size_t)p->width * channels ||
      stride > std::numeric_limits<size_t>::max() / (size_t)p->height ||
      byte_count < stride * (p->height - 1) + (size_t)p->width * channels)
    return 1;
  for (int i = 0; i < 4; i++)
    if (!std::isfinite(rectangle[i]) || std::abs(rectangle[i]) > 65536)
      return 1;
  if (rectangle[2] <= 0 || rectangle[3] <= 0)
    return 1;
  try {
    const cv::Mat input(p->height, p->width, CV_MAKETYPE(CV_8U, channels),
                        const_cast<uint8_t *>(pixels), stride);
    cv::remap(input, p->undistorted, p->mapX, p->mapY, cv::INTER_LINEAR, cv::BORDER_CONSTANT,
              cv::Scalar(128, 128, 128, 0));
    cv::resize(p->undistorted, p->scaled, cv::Size(), p->scale, p->scale, cv::INTER_AREA);
    const double x = rectangle[0], y = rectangle[1], w = rectangle[2], h = rectangle[3];
    std::vector<cv::Point2d> corners = {{x, y}, {x + w, y}, {x, y + h}, {x + w, y + h}}, corrected;
    cv::undistortPoints(corners, corrected, p->camera, p->distortion, cv::noArray(), p->camera);
    int xmin = INT_MAX, ymin = INT_MAX, xmax = INT_MIN, ymax = INT_MIN;
    for (const auto &point : corrected) {
      if (!std::isfinite(point.x) || !std::isfinite(point.y) || std::abs(point.x) > 1000000 ||
          std::abs(point.y) > 1000000)
        return 1;
      const int px = (int)std::round(point.x), py = (int)std::round(point.y);
      xmin = std::min(xmin, px);
      ymin = std::min(ymin, py);
      xmax = std::max(xmax, px);
      ymax = std::max(ymax, py);
    }
    geometry[0] = xmin;
    geometry[1] = ymin;
    geometry[2] = xmax - xmin;
    geometry[3] = ymax - ymin;
    geometry[4] = p->scaled.cols;
    geometry[5] = p->scaled.rows;
    const int originX =
        (int)(geometry[0] * (double)p->scale) + (int)(geometry[2] * (double)p->scale) / 2;
    const int originY =
        (int)(geometry[1] * (double)p->scale) + (int)(geometry[3] * (double)p->scale) / 2;
    geometry[6] = originX;
    geometry[7] = originY;
    if (originX < 0 || originY < 0 || originX > p->scaled.cols || originY > p->scaled.rows)
      return 1;
    cv::Mat padded, gray, resized;
    cv::copyMakeBorder(p->scaled, padded, 480, 480, 480, 480, cv::BORDER_CONSTANT,
                       cv::Scalar(128, 128, 128, 0));
    p->crop = padded(cv::Rect(originX, originY, 960, 960)).clone();
    if (channels == 3)
      cv::cvtColor(p->crop, gray, cv::COLOR_BGR2GRAY);
    else
      gray = p->crop;
    cv::resize(gray, resized, cv::Size(224, 224), 0, 0, cv::INTER_LINEAR);
    const float mean[3] = {.485f, .456f, .406f};
    const double divisor[3] = {.229, .224, .225};
    for (int channel = 0; channel < 3; channel++)
      for (int row = 0; row < 224; row++)
        for (int col = 0; col < 224; col++) {
          const float value = (float)resized.at<uint8_t>(row, col) * (1.0f / 255.0f);
          tensor[channel * 224 * 224 + row * 224 + col] =
              (float)((double)(value - mean[channel]) / divisor[channel]);
        }
    return 0;
  } catch (...) {
    return 2;
  }
}
int odyssey_depth_preparation_stage(OdysseyDepthPreparation *p, int stage, uint8_t *bytes,
                                    size_t capacity, size_t *count) {
  if (!p || !count || stage < 0 || stage > 2)
    return 1;
  const cv::Mat &mat = stage == 0 ? p->undistorted : stage == 1 ? p->scaled : p->crop;
  *count = mat.total() * mat.elemSize();
  if (!bytes)
    return capacity == 0 ? 0 : 1;
  if (capacity < *count)
    return 1;
  for (int row = 0; row < mat.rows; row++)
    std::memcpy(bytes + row * mat.cols * mat.elemSize(), mat.ptr(row), mat.cols * mat.elemSize());
  return 0;
}
