#include "OdysseyInference.h"
#include "onnxruntime_c_api.h"
#include <array>
#include <cmath>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

// Separate from the tracking sessions: conversion must not change their
// execution options or tensor contracts. Callers serialize each instance.
struct OdysseyMonocularDepth {
  const OrtApi *api = OrtGetApiBase()->GetApi(ORT_API_VERSION);
  OrtEnv *environment = nullptr;
  OrtSessionOptions *options = nullptr;
  OrtSession *session = nullptr;
  OrtMemoryInfo *memory = nullptr;
  std::string inputName, outputName;
  std::array<int64_t, 4> shape{};
  size_t pixels = 0;

  ~OdysseyMonocularDepth() {
    if (!api)
      return;
    if (memory)
      api->ReleaseMemoryInfo(memory);
    if (session)
      api->ReleaseSession(session);
    if (options)
      api->ReleaseSessionOptions(options);
    if (environment)
      api->ReleaseEnv(environment);
  }

  int check(OrtStatus *status) {
    if (!status)
      return 0;
    int code = static_cast<int>(api->GetErrorCode(status));
    api->ReleaseStatus(status);
    return code ? code : -1;
  }

  int initialize(const char *path, const char *cache = nullptr) {
    if (!api)
      return -1;
#define CHECK(call)                                                                                \
  do {                                                                                             \
    int code = check(call);                                                                        \
    if (code)                                                                                      \
      return code;                                                                                 \
  } while (0)
    CHECK(api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "MacdisseyConversion", &environment));
    CHECK(api->CreateSessionOptions(&options));
    CHECK(api->SetIntraOpNumThreads(options, 2));
    CHECK(api->SetInterOpNumThreads(options, 1));
    CHECK(api->SetSessionExecutionMode(options, ORT_SEQUENTIAL));
    CHECK(api->SetSessionGraphOptimizationLevel(options, ORT_ENABLE_ALL));
    if (cache) {
      const char *keys[] = {"ModelFormat", "MLComputeUnits", "RequireStaticInputShapes",
                            "ModelCacheDirectory"};
      const char *values[] = {"MLProgram", "CPUAndGPU", "0", cache};
      CHECK(api->SessionOptionsAppendExecutionProvider(options, "CoreML", keys, values, 4));
    }
    CHECK(api->CreateSession(environment, path, options, &session));
    CHECK(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory));
    size_t inputs = 0, outputs = 0;
    CHECK(api->SessionGetInputCount(session, &inputs));
    CHECK(api->SessionGetOutputCount(session, &outputs));
    if (inputs != 1 || outputs != 1)
      return -1;
    OrtAllocator *allocator = nullptr;
    CHECK(api->GetAllocatorWithDefaultOptions(&allocator));
    for (int index = 0; index < 2; ++index) {
      OrtTypeInfo *type = nullptr;
      CHECK(index == 0 ? api->SessionGetInputTypeInfo(session, 0, &type)
                       : api->SessionGetOutputTypeInfo(session, 0, &type));
      const OrtTensorTypeAndShapeInfo *tensor = nullptr;
      size_t rank = 0;
      ONNXTensorElementDataType element = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
      int code = check(api->CastTypeInfoToTensorInfo(type, &tensor));
      if (!code && !tensor)
        code = -1;
      if (!code)
        code = check(api->GetDimensionsCount(tensor, &rank));
      if (!code)
        code = check(api->GetTensorElementType(tensor, &element));
      std::array<int64_t, 4> dimensions{};
      if (!code && rank <= dimensions.size())
        code = check(api->GetDimensions(tensor, dimensions.data(), rank));
      api->ReleaseTypeInfo(type);
      if (code || element != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || rank != (index == 0 ? 4u : 3u))
        return code ? code : -1;
      if (index == 0) {
        // The recovered tiny and small/large models use these square inputs.
        if (dimensions[0] != 1 || dimensions[1] != 3 ||
            (dimensions[2] != 256 && dimensions[2] != 518) || dimensions[3] != dimensions[2])
          return -1;
        shape = dimensions;
        pixels = static_cast<size_t>(shape[2] * shape[3]);
      } else {
        // Tiny declares symbolic output dimensions. Validate concrete dimensions
        // after every invocation, before copying any output into caller memory.
        const std::array<int64_t, 3> expected{1, shape[2], shape[3]};
        for (size_t axis = 0; axis < expected.size(); ++axis)
          if (dimensions[axis] > 0 && dimensions[axis] != expected[axis])
            return -1;
      }
      char *name = nullptr;
      CHECK(index == 0 ? api->SessionGetInputName(session, 0, allocator, &name)
                       : api->SessionGetOutputName(session, 0, allocator, &name));
      if (!name)
        return -1;
      (index == 0 ? inputName : outputName) = name;
      allocator->Free(allocator, name);
    }
    return 0;
#undef CHECK
  }

  int invoke(const float *input, size_t inputCount, float *output, size_t outputCount) {
    if (!input || !output || inputCount != pixels * 3 || outputCount != pixels)
      return -1;
    for (size_t i = 0; i < inputCount; ++i)
      if (!std::isfinite(input[i]))
        return -1;
    OrtValue *source = nullptr, *result = nullptr;
    int code = check(api->CreateTensorWithDataAsOrtValue(
        memory, const_cast<float *>(input), inputCount * sizeof(float), shape.data(), shape.size(),
        ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &source));
    const char *in = inputName.c_str(), *out = outputName.c_str();
    if (!code)
      code = check(api->Run(session, nullptr, &in, &source, 1, &out, 1, &result));
    OrtTensorTypeAndShapeInfo *type = nullptr;
    if (!code)
      code = check(api->GetTensorTypeAndShape(result, &type));
    size_t rank = 0, count = 0;
    std::array<int64_t, 3> dimensions{};
    ONNXTensorElementDataType element = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
    if (!code)
      code = check(api->GetDimensionsCount(type, &rank));
    if (!code && rank != dimensions.size())
      code = -1;
    if (!code)
      code = check(api->GetDimensions(type, dimensions.data(), dimensions.size()));
    if (!code)
      code = check(api->GetTensorShapeElementCount(type, &count));
    if (!code)
      code = check(api->GetTensorElementType(type, &element));
    if (!code && (dimensions != std::array<int64_t, 3>{1, shape[2], shape[3]} || count != pixels ||
                  element != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT))
      code = -1;
    float *data = nullptr;
    if (!code)
      code = check(api->GetTensorMutableData(result, reinterpret_cast<void **>(&data)));
    if (!code)
      for (size_t i = 0; i < pixels; ++i)
        if (!std::isfinite(data[i])) {
          code = -1;
          break;
        }
    if (!code)
      std::memcpy(output, data, pixels * sizeof(float));
    if (type)
      api->ReleaseTensorTypeAndShapeInfo(type);
    if (result)
      api->ReleaseValue(result);
    if (source)
      api->ReleaseValue(source);
    return code;
  }
};

OdysseyMonocularDepth *odyssey_monocular_create(const char *path, int *side, int *status) {
  if (!side || !status)
    return nullptr;
  *side = 0;
  *status = -1;
  if (!path)
    return nullptr;
  try {
    auto model = std::make_unique<OdysseyMonocularDepth>();
    *status = model->initialize(path);
    if (*status)
      return nullptr;
    *side = static_cast<int>(model->shape[2]);
    return model.release();
  } catch (...) {
    *status = -1;
    return nullptr;
  }
}

// Compile and warm the accelerated model before capture/optical output starts.
// Failure leaves the caller free to create the reference CPU implementation.
OdysseyMonocularDepth *odyssey_monocular_create_accelerated(const char *path, const char *cache,
                                                            int *side, int *status) {
  if (!side || !status)
    return nullptr;
  *side = 0;
  *status = -1;
  if (!path || !cache)
    return nullptr;
  try {
    auto model = std::make_unique<OdysseyMonocularDepth>();
    *status = model->initialize(path, cache);
    if (*status)
      return nullptr;
    std::vector<float> input(model->pixels * 3, 0), output(model->pixels);
    *status = model->invoke(input.data(), input.size(), output.data(), output.size());
    if (*status)
      return nullptr;
    *side = static_cast<int>(model->shape[2]);
    return model.release();
  } catch (...) {
    *status = -1;
    return nullptr;
  }
}

void odyssey_monocular_destroy(OdysseyMonocularDepth *model) { delete model; }

int odyssey_monocular_invoke(OdysseyMonocularDepth *model, const float *input, size_t inputCount,
                             float *output, size_t outputCount) {
  if (!model)
    return -1;
  try {
    return model->invoke(input, inputCount, output, outputCount);
  } catch (...) {
    return -1;
  }
}
