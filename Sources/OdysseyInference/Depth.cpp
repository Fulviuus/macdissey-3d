#include "OdysseyInference.h"
#include "OnnxModel.h"
#include <memory>

struct OdysseyDepthModel : OdysseyOnnxModel {};
OdysseyDepthModel *odyssey_depth_create(const char *path, int *status) {
  if (!status)
    return nullptr;
  *status = -1;
  if (!path)
    return nullptr;
  try {
    std::unique_ptr<OdysseyDepthModel> result(new OdysseyDepthModel());
    *status = result->initialize(path, {{1, 3, 224, 224}, {1, 2}});
    return *status == 0 ? result.release() : nullptr;
  } catch (...) {
    return nullptr;
  }
}
void odyssey_depth_destroy(OdysseyDepthModel *model) { delete model; }
int odyssey_depth_invoke(OdysseyDepthModel *model, const float *input, size_t input_count,
                         float *output, size_t output_count) {
  if (!model)
    return -1;
  try {
    return model->invoke(input, input_count, output, output_count);
  } catch (...) {
    return -1;
  }
}
