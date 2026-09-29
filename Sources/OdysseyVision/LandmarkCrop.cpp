#include "OdysseyVision.h"
#include <cmath>
#include <limits>
#include <opencv2/imgproc.hpp>

extern "C" int odyssey_landmark_crop(const uint8_t *pixels, size_t byte_count, int width,
                                     int height, size_t stride, const float *region, float *tensor,
                                     size_t tensor_count, float *adjusted) {
  if (!pixels || !region || !tensor || !adjusted || width < 1 || height < 1 || width > 8192 ||
      height > 8192 || stride < (size_t)width ||
      stride > std::numeric_limits<size_t>::max() / (size_t)height ||
      byte_count < stride * (size_t)(height - 1) + (size_t)width || tensor_count != 192 * 192)
    return 1;
  for (int i = 0; i < 5; i++)
    if (!std::isfinite(region[i]))
      return 1;
  if (region[2] <= 0 || region[3] <= 0)
    return 1;
  try {
    const float imageWidth = (float)width, imageHeight = (float)height;
    const float centerX = imageWidth * region[0], centerY = imageHeight * region[1];
    float cropWidth = imageWidth * region[2], cropHeight = imageHeight * region[3];
    if (1.0f <= cropHeight / cropWidth)
      cropWidth = cropHeight / 1.0f;
    else
      cropHeight = 1.0f * cropWidth;
    if (!std::isfinite(centerX) || !std::isfinite(centerY) || !std::isfinite(cropWidth) ||
        !std::isfinite(cropHeight))
      return 1;
    adjusted[0] = centerX / imageWidth;
    adjusted[1] = centerY / imageHeight;
    adjusted[2] = cropWidth / imageWidth;
    adjusted[3] = cropHeight / imageHeight;
    adjusted[4] = region[4];
    const float degrees = (float)((double)(region[4] * 180.0f) / CV_PI);
    const cv::RotatedRect box(cv::Point2f(centerX, centerY), cv::Size2f(cropWidth, cropHeight),
                              degrees);
    cv::Point2f source[4], destination[4] = {{0, 192}, {0, 0}, {192, 0}, {192, 192}};
    box.points(source);
    const cv::Mat transform = cv::getPerspectiveTransform(source, destination, cv::DECOMP_LU);
    const cv::Mat input(height, width, CV_8UC1, const_cast<uint8_t *>(pixels), stride);
    cv::Mat warped, output(192, 192, CV_32FC1, tensor);
    cv::warpPerspective(input, warped, transform, cv::Size(192, 192), cv::INTER_LINEAR,
                        cv::BORDER_REPLICATE, cv::Scalar());
    warped.convertTo(output, CV_32FC1, 1.0, 0.0);
    return 0;
  } catch (...) {
    return 2;
  }
}
