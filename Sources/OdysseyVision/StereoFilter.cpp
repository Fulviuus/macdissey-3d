#include "OdysseyVision.h"
#include <cmath>
#include <opencv2/core.hpp>

int odyssey_stereo_fit(const double *timestamps, const float *left, const float *right,
                       size_t count, int order, float *output) {
  if (!timestamps || !left || !right || !output || !count || count > 256 || order < 0 || order > 3)
    return 1;
  for (size_t i = 0; i < count; i++)
    if (!std::isfinite(timestamps[i]))
      return 1;
  for (size_t i = 0; i < count * 4; i++)
    if (!std::isfinite(left[i]) || !std::isfinite(right[i]))
      return 1;
  for (int i = 0; i < 2; i++) {
    output[i] = left[(count - 1) * 4 + i];
    output[i + 2] = right[(count - 1) * 4 + i];
    output[i + 4] = left[(count - 1) * 4 + i + 2];
    output[i + 6] = right[(count - 1) * 4 + i + 2];
  }
  if (count <= (size_t)(order + 6))
    return 0;
  try {
    const int columns = 4 + order + (order > 0);
    cv::Mat design = cv::Mat::zeros((int)count * 4, columns, CV_32F);
    cv::Mat x((int)count * 4, 1, CV_32F), y((int)count * 4, 1, CV_32F);
    for (size_t i = 0; i < count; i++) {
      const float time = (float)(timestamps[i] - timestamps[count - 1]);
      for (int row = 0; row < 4; row++) {
        float *a = design.ptr<float>((int)i * 4 + row);
        a[row < 2 ? 0 : 2] = 1;
        if (row % 2)
          a[row < 2 ? 1 : 3] = 1;
        if (order > 0) {
          a[4] = time;
          a[5] = row < 2 ? 0 : time;
        }
        if (order > 1)
          a[6] = time * time;
        if (order > 2)
          a[7] = (time * time) * time;
        const float *sample = row < 2 ? left + i * 4 : right + i * 4;
        x.at<float>((int)i * 4 + row) = sample[(row % 2) * 2];
        y.at<float>((int)i * 4 + row) = sample[(row % 2) * 2 + 1];
      }
    }
    // Preserve the original normal-equation evaluation and float matrices.
    cv::Mat xFit = (design.t() * design).inv() * design.t() * x;
    cv::Mat yFit = (design.t() * design).inv() * design.t() * y;
    output[0] = xFit.at<float>(0);
    output[2] = xFit.at<float>(2);
    output[4] = xFit.at<float>(1) + xFit.at<float>(0);
    output[6] = xFit.at<float>(3) + xFit.at<float>(2);
    output[1] = yFit.at<float>(0);
    output[3] = yFit.at<float>(2);
    output[5] = yFit.at<float>(1) + yFit.at<float>(0);
    output[7] = yFit.at<float>(3) + yFit.at<float>(2);
    for (int i = 0; i < 8; i++)
      if (!std::isfinite(output[i]))
        return 2;
    return 0;
  } catch (...) {
    return 2;
  }
}
