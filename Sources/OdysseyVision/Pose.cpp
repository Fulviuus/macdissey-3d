#include "OdysseyVision.h"
#include <cmath>
#include <opencv2/calib3d.hpp>
#include <vector>

// Reconstructed Blink 1.11.0 path at RVA 0x132ca70. Preserve the selected
// landmark order, mirrored coordinates, first-column scale, and negative-Z
// retry. Preserve this numerical behavior when updating the vision dependency.
extern "C" int odyssey_solve_pose(const double *model, const double *pixels, const int32_t *subset,
                                  size_t count, const double *camera_data,
                                  const double *distortion_data, double width, double ratio,
                                  int euler, double *output) {
  if (!model || !pixels || !subset || !camera_data || !distortion_data || !output || count < 6 ||
      count > 68 || !std::isfinite(width) || width <= 0 || !std::isfinite(ratio))
    return 1;
  for (size_t i = 0; i < 204; ++i)
    if (!std::isfinite(model[i]))
      return 1;
  for (size_t i = 0; i < 136; ++i)
    if (!std::isfinite(pixels[i]))
      return 1;
  for (size_t i = 0; i < 9; ++i)
    if (!std::isfinite(camera_data[i]))
      return 1;
  for (size_t i = 0; i < 8; ++i)
    if (!std::isfinite(distortion_data[i]))
      return 1;
  if (camera_data[0] <= 0 || camera_data[4] <= 0)
    return 1;
  try {
    std::vector<cv::Point3d> world;
    std::vector<cv::Point2d> image;
    world.reserve(count);
    image.reserve(count);
    for (size_t j = 0; j < count; ++j) {
      const int p = subset[j];
      if (p < 0 || p >= 68)
        return 1;
      world.emplace_back(model[3 * p] * ratio, model[3 * p + 1], model[3 * p + 2]);
      image.emplace_back(width - pixels[2 * p], pixels[2 * p + 1]);
    }
    double k[9], d[8];
    std::copy(camera_data, camera_data + 9, k);
    std::copy(distortion_data, distortion_data + 8, d);
    k[2] = width - k[2];
    cv::Mat camera(3, 3, CV_64F, k), distortion(8, 1, CV_64F, d), r, t;
    bool ok = cv::solvePnP(world, image, camera, distortion, r, t, false, cv::SOLVEPNP_ITERATIVE);
    if (ok && t.at<double>(2) < 0) {
      t.convertTo(t, -1, -1);
      r.setTo(0);
      ok = cv::solvePnP(world, image, camera, distortion, r, t, true, cv::SOLVEPNP_ITERATIVE);
    }
    if (!ok)
      return 2;
    double result[6] = {t.at<double>(0), t.at<double>(1), t.at<double>(2),
                        r.at<double>(0), r.at<double>(1), r.at<double>(2)};
    if (euler) {
      cv::Mat matrix;
      cv::Rodrigues(r, matrix);
      result[3] = atan2(matrix.at<double>(2, 1), matrix.at<double>(2, 2));
      result[4] = -asin(matrix.at<double>(2, 0));
      const double cosine = cos(result[4]);
      result[5] = atan2(matrix.at<double>(1, 0) / cosine, matrix.at<double>(0, 0) / cosine);
    }
    for (double value : result)
      if (!std::isfinite(value))
        return 2;
    std::copy(result, result + 6, output);
    return 0;
  } catch (...) {
    return 2;
  }
}
