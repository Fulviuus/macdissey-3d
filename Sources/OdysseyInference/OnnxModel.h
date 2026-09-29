#pragma once
#include "onnxruntime_c_api.h"
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

// Owns one fixed-shape CPU ONNX session. Callers serialize inference per model.
class OdysseyOnnxModel {
public:
  const OrtApi *api = OrtGetApiBase()->GetApi(ORT_API_VERSION);
  OrtEnv *environment = nullptr;
  OrtSessionOptions *options = nullptr;
  OrtSession *session = nullptr;
  OrtMemoryInfo *memory = nullptr;
  std::vector<std::string> names;
  std::vector<std::vector<int64_t>> shapes;
  std::vector<size_t> sizes;
  ~OdysseyOnnxModel() {
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
    const int code = (int)api->GetErrorCode(status);
    api->ReleaseStatus(status);
    return code ? code : -1;
  }
  int initialize(const char *path, const std::vector<std::vector<int64_t>> &expected) {
    if (!api || !path || expected.size() < 2)
      return -1;
#define ORT_CHECK(call)                                                                            \
  do {                                                                                             \
    const int result = check(call);                                                                \
    if (result)                                                                                    \
      return result;                                                                               \
  } while (0)
    ORT_CHECK(api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "OdysseyTracking", &environment));
    ORT_CHECK(api->CreateSessionOptions(&options));
    ORT_CHECK(api->SetIntraOpNumThreads(options, 2));
    ORT_CHECK(api->SetInterOpNumThreads(options, 1));
    ORT_CHECK(api->SetSessionExecutionMode(options, ORT_SEQUENTIAL));
    ORT_CHECK(api->SetSessionGraphOptimizationLevel(options, ORT_ENABLE_ALL));
    ORT_CHECK(api->CreateSession(environment, path, options, &session));
    ORT_CHECK(api->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory));
    size_t inputs = 0, outputs = 0;
    ORT_CHECK(api->SessionGetInputCount(session, &inputs));
    ORT_CHECK(api->SessionGetOutputCount(session, &outputs));
    if (inputs != 1 || outputs != expected.size() - 1)
      return -1;
    OrtAllocator *allocator = nullptr;
    ORT_CHECK(api->GetAllocatorWithDefaultOptions(&allocator));
    for (size_t index = 0; index < expected.size(); index++) {
      OrtTypeInfo *type = nullptr;
      ORT_CHECK(index == 0 ? api->SessionGetInputTypeInfo(session, 0, &type)
                           : api->SessionGetOutputTypeInfo(session, index - 1, &type));
      const OrtTensorTypeAndShapeInfo *tensor = nullptr;
      int code = check(api->CastTypeInfoToTensorInfo(type, &tensor));
      size_t rank = 0;
      ONNXTensorElementDataType element = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
      if (!code && tensor)
        code = check(api->GetDimensionsCount(tensor, &rank));
      if (!code && tensor)
        code = check(api->GetTensorElementType(tensor, &element));
      std::vector<int64_t> dimensions(expected[index].size());
      if (!code && rank == dimensions.size())
        code = check(api->GetDimensions(tensor, dimensions.data(), rank));
      api->ReleaseTypeInfo(type);
      if (code)
        return code;
      if (rank != dimensions.size() || element != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT ||
          dimensions != expected[index])
        return -1;
      char *name = nullptr;
      ORT_CHECK(index == 0 ? api->SessionGetInputName(session, 0, allocator, &name)
                           : api->SessionGetOutputName(session, index - 1, allocator, &name));
      if (!name)
        return -1;
      names.emplace_back(name);
      allocator->Free(allocator, name);
      size_t size = 1;
      for (auto dimension : dimensions)
        size *= dimension;
      sizes.push_back(size);
    }
    shapes = expected;
    return 0;
#undef ORT_CHECK
  }
  int invoke(const float *input, size_t inputCount, float *output, size_t outputCount) {
    if (!session || !input || !output || sizes.empty() || inputCount != sizes[0])
      return -1;
    size_t total = 0;
    for (size_t i = 1; i < sizes.size(); i++)
      total += sizes[i];
    if (outputCount != total)
      return -1;
    for (size_t i = 0; i < inputCount; i++)
      if (!std::isfinite(input[i]))
        return -1;
    OrtValue *inputValue = nullptr;
    std::vector<OrtValue *> values(sizes.size() - 1, nullptr);
    std::vector<const char *> outputNames;
    for (size_t i = 1; i < names.size(); i++)
      outputNames.push_back(names[i].c_str());
    int code = check(api->CreateTensorWithDataAsOrtValue(
        memory, const_cast<float *>(input), inputCount * sizeof(float), shapes[0].data(),
        shapes[0].size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &inputValue));
    const char *inputName = names[0].c_str();
    if (!code)
      code = check(api->Run(session, nullptr, &inputName, &inputValue, 1, outputNames.data(),
                            values.size(), values.data()));
    size_t offset = 0;
    for (size_t i = 0; i < values.size(); i++) {
      if (!code) {
        void *data = nullptr;
        code = check(api->GetTensorMutableData(values[i], &data));
        if (!code)
          std::memcpy(output + offset, data, sizes[i + 1] * sizeof(float));
      }
      offset += sizes[i + 1];
      if (values[i])
        api->ReleaseValue(values[i]);
    }
    if (inputValue)
      api->ReleaseValue(inputValue);
    if (!code)
      for (size_t i = 0; i < outputCount; i++)
        if (!std::isfinite(output[i]))
          return -1;
    return code;
  }
};
