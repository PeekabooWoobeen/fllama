class FllamaInferenceRequest {
  int contextSize; // llama.cpp handled 0 fine. StableLM Zephyr became default (4096).
  String? ggmlMetalPath;
  String input;
  int maxTokens;
  String modelPath;
  int numGpuLayers;
  double temperature;
  double topP;

  FllamaInferenceRequest({
    this.ggmlMetalPath,
    required this.contextSize,
    required this.input,
    required this.maxTokens,
    required this.modelPath,
    required this.numGpuLayers,
    required this.temperature,
    required this.topP,
  });
}