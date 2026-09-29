#include "OdysseyVision.h"
#include <algorithm>
#include <cmath>
#include <opencv2/calib3d.hpp>
#include <vector>

int odyssey_stereo_triangulate(const double *left_camera, const double *left_distortion,
                               const double *right_camera, const double *right_distortion,
                               const double *rotation, const double *translation,
                               const float *pixels, double minimum_depth, double maximum_error,
                               float *point, double *reprojection_error, int *accepted) {
  if (!left_camera || !left_distortion || !right_camera || !right_distortion || !rotation ||
      !translation || !pixels || !point || !reprojection_error || !accepted ||
      !std::isfinite(minimum_depth) || !std::isfinite(maximum_error) || maximum_error < 0)
    return 1;
  for (int i = 0; i < 9; i++)
    if (!std::isfinite(left_camera[i]) || !std::isfinite(right_camera[i]) ||
        !std::isfinite(rotation[i]))
      return 1;
  for (int i = 0; i < 8; i++)
    if (!std::isfinite(left_distortion[i]) || !std::isfinite(right_distortion[i]))
      return 1;
  for (int i = 0; i < 3; i++)
    if (!std::isfinite(translation[i]))
      return 1;
  for (int i = 0; i < 4; i++)
    if (!std::isfinite(pixels[i]))
      return 1;
  try {
    const cv::Mat k0(3, 3, CV_64F, const_cast<double *>(left_camera)),
        k1(3, 3, CV_64F, const_cast<double *>(right_camera));
    const cv::Mat d0(1, 8, CV_64F, const_cast<double *>(left_distortion)),
        d1(1, 8, CV_64F, const_cast<double *>(right_distortion));
    const cv::Mat r(3, 3, CV_64F, const_cast<double *>(rotation)),
        t(3, 1, CV_64F, const_cast<double *>(translation));
    const cv::Mat identity = cv::Mat::eye(3, 3, CV_64F), zero = cv::Mat::zeros(3, 1, CV_64F);
    cv::Mat projection0, projection1, homogeneous;
    cv::hconcat(identity, zero, projection0);
    cv::hconcat(r, t, projection1);
    std::vector<cv::Point2d> left = {{(double)pixels[0], (double)pixels[1]}},
                             right = {{(double)pixels[2], (double)pixels[3]}};
    cv::undistortPoints(left, left, k0, d0);
    cv::undistortPoints(right, right, k1, d1);
    cv::triangulatePoints(projection0, projection1, left, right, homogeneous);
    const double inverse = 1.0 / homogeneous.at<double>(3, 0);
    for (int axis = 0; axis < 3; axis++)
      point[axis] = (float)(inverse * homogeneous.at<double>(axis, 0));
    if (!std::isfinite(point[0]) || !std::isfinite(point[1]) || !std::isfinite(point[2]))
      return 2;
    // The original projects the rounded float point, and returns float pixel
    // coordinates promoted back to double for its rejection calculation.
    const std::vector<cv::Point3f> object = {{point[0], point[1], point[2]}};
    std::vector<cv::Point2f> projected0, projected1;
    cv::Mat rotationVector0, rotationVector1;
    cv::Rodrigues(identity, rotationVector0);
    cv::Rodrigues(r, rotationVector1);
    cv::projectPoints(object, rotationVector0, zero, k0, d0, projected0);
    cv::projectPoints(object, rotationVector1, t, k1, d1, projected1);
    const double x0 = (double)pixels[0] - projected0[0].x, y0 = (double)pixels[1] - projected0[0].y;
    const double x1 = (double)pixels[2] - projected1[0].x, y1 = (double)pixels[3] - projected1[0].y;
    *reprojection_error = std::max(std::sqrt(x1 * x1 + y1 * y1), std::sqrt(x0 * x0 + y0 * y0));
    *accepted = *reprojection_error <= maximum_error && minimum_depth <= (double)point[2];
    return 0;
  } catch (...) {
    return 2;
  }
}
