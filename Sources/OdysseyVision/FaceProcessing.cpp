#include "DetectionOrder.h"
#include "OdysseyVision.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <opencv2/imgproc.hpp>
#include <vector>

int odyssey_face_letterbox(const uint8_t *pixels, size_t byte_count, int width, int height,
                           size_t stride, float *tensor, size_t tensor_count, int32_t *padding) {
  if (!pixels || !tensor || !padding || width < 1 || height < 1 || width > 8192 || height > 8192 ||
      stride < (size_t)width || stride > std::numeric_limits<size_t>::max() / (size_t)height ||
      byte_count < stride * (size_t)(height - 1) + (size_t)width || tensor_count != 448 * 320)
    return 1;
  try {
    const float ratio = std::min(448.0f / (float)width, 320.0f / (float)height);
    const int w = (int)std::round((float)width * ratio), h = (int)std::round((float)height * ratio);
    if (w < 1 || h < 1 || w > 448 || h > 320)
      return 1;
    padding[0] = (448 - w) / 2;
    padding[1] = 448 - w - padding[0];
    padding[2] = (320 - h) / 2;
    padding[3] = 320 - h - padding[2];
    const cv::Mat input(height, width, CV_8UC1, const_cast<uint8_t *>(pixels), stride);
    cv::Mat resized;
    if (w == width && h == height)
      resized = input.clone();
    else
      cv::resize(input, resized, cv::Size(w, h), 0, 0, cv::INTER_LINEAR);
    cv::copyMakeBorder(resized, resized, padding[2], padding[3], padding[0], padding[1],
                       cv::BORDER_CONSTANT, cv::Scalar(114));
    cv::Mat output(320, 448, CV_32FC1, tensor);
    resized.convertTo(output, CV_32FC1, (double)(1.0f / 255.0f), 0.0);
    return 0;
  } catch (...) {
    return 2;
  }
}

using Detection = std::array<float, 20>;
int odyssey_face_clahe(const uint8_t *pixels, size_t byte_count, int width, int height,
                       size_t stride, uint8_t *output, size_t output_count) {
  if (!pixels || !output || width < 1 || height < 1 || width > 8192 || height > 8192 ||
      stride < (size_t)width || stride > std::numeric_limits<size_t>::max() / (size_t)height ||
      byte_count < stride * (size_t)(height - 1) + (size_t)width ||
      output_count != (size_t)width * height)
    return 1;
  try {
    const cv::Mat input(height, width, CV_8UC1, const_cast<uint8_t *>(pixels), stride);
    cv::Mat result(height, width, CV_8UC1, output);
    cv::createCLAHE(40.0, cv::Size(8, 8))->apply(input, result);
    return 0;
  } catch (...) {
    return 2;
  }
}
// Preserve OpenCV's original intersection operation order, including negative
// rectangle coordinates, rather than an algebraically rearranged IoU formula.
static float overlap(const Detection &a, const Detection &b) {
  float w = 0, h = 0;
  if (a[2] > 0 && a[3] > 0 && b[2] > 0 && b[3] > 0) {
    const auto &xmin = a[0] < b[0] ? a : b, &xmax = a[0] < b[0] ? b : a;
    const auto &ymin = a[1] < b[1] ? a : b, &ymax = a[1] < b[1] ? b : a;
    if ((xmin[0] >= 0 || xmax[0] <= xmin[0] + xmin[2]) &&
        (ymin[1] >= 0 || ymax[1] <= ymin[1] + ymin[3])) {
      w = std::min(xmax[2], xmin[2] - (xmax[0] - xmin[0]));
      h = std::min(ymax[3], ymin[3] - (ymax[1] - ymin[1]));
      if (w <= 0 || h <= 0)
        w = h = 0;
    }
  }
  const float denominator = (a[3] * a[2] + b[3] * b[2]) - h * w;
  return denominator > 0 ? (h * w) / denominator : 0;
}

int odyssey_face_decode(const float *tensor, size_t tensor_count, const int32_t *padding,
                        float threshold, float nms, float *detections, size_t capacity,
                        size_t *count) {
  if (!tensor || !padding || !count || (!detections && capacity) || tensor_count != 141120 ||
      !std::isfinite(threshold) || threshold < 0 || threshold > 1 || !std::isfinite(nms) ||
      nms < 0 || nms > 1)
    return 1;
  for (int i = 0; i < 4; i++)
    if (padding[i] < 0)
      return 1;
  if ((int64_t)padding[0] + padding[1] >= 448 || (int64_t)padding[2] + padding[3] >= 320)
    return 1;
  for (size_t i = 0; i < tensor_count; i++)
    if (!std::isfinite(tensor[i]))
      return 1;
  try {
    const int strides[3] = {8, 16, 32}, anchors[3][6] = {{4, 5, 8, 10, 13, 16},
                                                         {23, 29, 43, 55, 73, 105},
                                                         {146, 217, 231, 300, 335, 433}};
    std::vector<Detection> candidates;
    size_t offset = 0;
    for (int layer = 0; layer < 3; layer++) {
      const int stride = strides[layer], width = 448 / stride, height = 320 / stride,
                area = width * height;
      for (int anchor = 0; anchor < 3; anchor++)
        for (int y = 0; y < height; y++)
          for (int x = 0; x < width; x++) {
            const float *cell = tensor + offset + anchor * 16 * area + y * width + x;
            const float confidence = (1.0f / (std::exp(-cell[15 * area]) + 1.0f)) *
                                     (1.0f / (std::exp(-cell[4 * area]) + 1.0f));
            if (!(confidence > threshold))
              continue;
            const int aw = anchors[layer][anchor * 2], ah = anchors[layer][anchor * 2 + 1];
            const float w =
                (float)((double)aw *
                        std::pow((double)(2.0f / (std::exp(-cell[2 * area]) + 1.0f)), 2.0));
            const float h =
                (float)((double)ah *
                        std::pow((double)(2.0f / (std::exp(-cell[3 * area]) + 1.0f)), 2.0));
            if (!(w > 0 && h > 0))
              continue;
            Detection d = {};
            d[0] = (float)(((double)(2.0f / (std::exp(-cell[0]) + 1.0f)) - .5 + (double)x) *
                           (double)stride) -
                   w * .5f;
            d[1] = (float)(((double)(2.0f / (std::exp(-cell[area]) + 1.0f)) - .5 + (double)y) *
                           (double)stride) -
                   h * .5f;
            d[2] = w;
            d[3] = h;
            d[19] = confidence;
            for (int point = 0; point < 5; point++) {
              d[4 + point * 3] = (float)aw * cell[(5 + point * 2) * area] + (float)(x * stride);
              d[5 + point * 3] = (float)ah * cell[(6 + point * 2) * area] + (float)(y * stride);
            }
            candidates.push_back(d);
          }
      offset += 48 * area;
    }
    odyssey_detection_order::sort(
        candidates.begin(), candidates.end(), candidates.size(),
        [](const Detection &a, const Detection &b) { return a[19] > b[19]; });
    std::vector<Detection> accepted;
    for (const auto &candidate : candidates) {
      bool suppressed = false;
      for (const auto &prior : accepted)
        if (overlap(prior, candidate) > nms) {
          suppressed = true;
          break;
        }
      if (!suppressed)
        accepted.push_back(candidate);
    }
    *count = accepted.size();
    if (*count > capacity)
      return 3;
    const float w = (float)(448 - padding[0] - padding[1]),
                h = (float)(320 - padding[2] - padding[3]);
    for (size_t i = 0; i < accepted.size(); i++) {
      auto d = accepted[i];
      d[0] = (d[0] - (float)padding[0]) / w;
      d[1] = (d[1] - (float)padding[2]) / h;
      d[2] /= w;
      d[3] /= h;
      for (int point = 0; point < 5; point++) {
        d[4 + point * 3] = (d[4 + point * 3] - (float)padding[0]) / w;
        d[5 + point * 3] = (d[5 + point * 3] - (float)padding[2]) / h;
      }
      std::copy(d.begin(), d.end(), detections + i * 20);
    }
    return 0;
  } catch (...) {
    return 2;
  }
}
