#include "OdysseyInference.h"
#include "litert/c/litert_compiled_model.h"
#include "litert/c/litert_environment.h"
#include "litert/c/litert_model.h"
#include "litert/c/litert_options.h"
#include "litert/c/litert_tensor_buffer.h"
#include <cmath>
#include <cstring>
#include <memory>

struct OdysseyLandmarkModel {
  LiteRtEnvironment environment = nullptr;
  LiteRtModel model = nullptr;
  LiteRtOptions options = nullptr;
  LiteRtCompiledModel compiled = nullptr;
  LiteRtTensorBuffer input = nullptr, output[2] = {nullptr, nullptr};
  ~OdysseyLandmarkModel() {
    for (auto buffer : output)
      if (buffer)
        LiteRtDestroyTensorBuffer(buffer);
    if (input)
      LiteRtDestroyTensorBuffer(input);
    if (compiled)
      LiteRtDestroyCompiledModel(compiled);
    if (options)
      LiteRtDestroyOptions(options);
    if (model)
      LiteRtDestroyModel(model);
    if (environment)
      LiteRtDestroyEnvironment(environment);
  }
  int initialize(const char *path);
};
#define CHECK(call)                                                                                \
  do {                                                                                             \
    const int status = (call);                                                                     \
    if (status)                                                                                    \
      return status;                                                                               \
  } while (0)
int OdysseyLandmarkModel::initialize(const char *path) {
  CHECK(LiteRtCreateEnvironment(0, nullptr, &environment));
  CHECK(LiteRtCreateModelFromFile(environment, path, &model));
  LiteRtParamIndex mainIndex = 0, count = 0;
  LiteRtSubgraph graph = nullptr;
  CHECK(LiteRtGetMainModelSubgraphIndex(model, &mainIndex));
  CHECK(LiteRtGetModelSubgraph(model, mainIndex, &graph));
  CHECK(LiteRtGetNumSubgraphInputs(graph, &count));
  if (count != 1)
    return -1;
  CHECK(LiteRtGetNumSubgraphOutputs(graph, &count));
  if (count != 2)
    return -1;
  LiteRtRankedTensorType types[3];
  for (int i = 0; i < 3; i++) {
    LiteRtTensor tensor = nullptr;
    if (i == 0) {
      CHECK(LiteRtGetSubgraphInput(graph, 0, &tensor));
    } else {
      CHECK(LiteRtGetSubgraphOutput(graph, i - 1, &tensor));
    }
    CHECK(LiteRtGetRankedTensorType(tensor, &types[i]));
    const auto &type = types[i];
    if (type.element_type != kLiteRtElementTypeFloat32)
      return -1;
    if (i == 0) {
      if (type.layout.rank != 4 || type.layout.dimensions[0] != 1 ||
          type.layout.dimensions[1] != 192 || type.layout.dimensions[2] != 192 ||
          type.layout.dimensions[3] != 1)
        return -1;
    } else if (type.layout.rank != 2 || type.layout.dimensions[0] != 1 ||
               type.layout.dimensions[1] != (i == 1 ? 396 : 1))
      return -1;
  }
  CHECK(LiteRtCreateOptions(&options));
  CHECK(LiteRtSetOptionsHardwareAccelerators(options, kLiteRtHwAcceleratorCpu));
  CHECK(LiteRtCreateCompiledModel(environment, model, options, &compiled));
  for (int i = 0; i < 3; i++) {
    LiteRtTensorBufferRequirements requirements = nullptr;
    if (i == 0) {
      CHECK(LiteRtGetCompiledModelInputBufferRequirements(compiled, 0, 0, &requirements));
    } else {
      CHECK(LiteRtGetCompiledModelOutputBufferRequirements(compiled, 0, i - 1, &requirements));
    }
    auto destination = i == 0 ? &input : &output[i - 1];
    CHECK(LiteRtCreateManagedTensorBufferFromRequirements(environment, &types[i], requirements,
                                                          destination));
    size_t bytes = 0;
    CHECK(LiteRtGetTensorBufferPackedSize(*destination, &bytes));
    if (bytes != (i == 0 ? 192 * 192 : i == 1 ? 396 : 1) * sizeof(float))
      return -1;
  }
  return 0;
}
OdysseyLandmarkModel *odyssey_landmark_create(const char *path, int *status) {
  if (!status)
    return nullptr;
  *status = -1;
  if (!path)
    return nullptr;
  try {
    std::unique_ptr<OdysseyLandmarkModel> result(new OdysseyLandmarkModel());
    *status = result->initialize(path);
    return *status == 0 ? result.release() : nullptr;
  } catch (...) {
    *status = -1;
    return nullptr;
  }
}
void odyssey_landmark_destroy(OdysseyLandmarkModel *model) { delete model; }
int odyssey_landmark_invoke(OdysseyLandmarkModel *model, const float *input, size_t input_count,
                            float *coordinates, size_t output_count, float *logit) {
  if (!model || !input || !coordinates || !logit || input_count != 192 * 192 || output_count != 396)
    return -1;
  for (size_t i = 0; i < input_count; i++)
    if (!std::isfinite(input[i]))
      return -1;
  try {
    void *data = nullptr;
    CHECK(LiteRtLockTensorBuffer(model->input, &data, kLiteRtTensorBufferLockModeWrite));
    std::memcpy(data, input, input_count * sizeof(float));
    CHECK(LiteRtUnlockTensorBuffer(model->input));
    CHECK(LiteRtRunCompiledModel(model->compiled, 0, 1, &model->input, 2, model->output));
    for (int i = 0; i < 2; i++) {
      CHECK(LiteRtLockTensorBuffer(model->output[i], &data, kLiteRtTensorBufferLockModeRead));
      std::memcpy(i == 0 ? coordinates : logit, data, (i == 0 ? 396 : 1) * sizeof(float));
      CHECK(LiteRtUnlockTensorBuffer(model->output[i]));
    }
    for (size_t i = 0; i < output_count; i++)
      if (!std::isfinite(coordinates[i]))
        return -1;
    return std::isfinite(*logit) ? 0 : -1;
  } catch (...) {
    return -1;
  }
}
