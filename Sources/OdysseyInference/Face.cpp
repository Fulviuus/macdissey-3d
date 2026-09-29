#include "OdysseyInference.h"
#include "OnnxModel.h"
#include <memory>

struct OdysseyFaceModel : OdysseyOnnxModel {};
OdysseyFaceModel *odyssey_face_create(const char *path, int *status) {
  if (!status)
    return nullptr;
  *status = -1;
  if (!path)
    return nullptr;
  try {
    std::unique_ptr<OdysseyFaceModel> result(new OdysseyFaceModel());
    *status = result->initialize(
        path, {{1, 1, 320, 448}, {1, 48, 40, 56}, {1, 48, 20, 28}, {1, 48, 10, 14}});
    return *status == 0 ? result.release() : nullptr;
  } catch (...) {
    return nullptr;
  }
}
void odyssey_face_destroy(OdysseyFaceModel *model) { delete model; }
int odyssey_face_invoke(OdysseyFaceModel *model, const float *input, size_t input_count,
                        float *output, size_t output_count) {
  if (!model)
    return -1;
  try {
    return model->invoke(input, input_count, output, output_count);
  } catch (...) {
    return -1;
  }
}
