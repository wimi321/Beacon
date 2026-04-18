import '../models/model_models.dart';

class ModelInferenceInput {
  const ModelInferenceInput({
    required this.systemPrompt,
    required this.userPrompt,
    required this.profile,
    required this.sessionId,
    this.resetContext = false,
    this.imageBytes,
  });

  final String systemPrompt;
  final String userPrompt;
  final ModelProfile profile;
  final String sessionId;
  final bool resetContext;
  final List<int>? imageBytes;
}

class ModelInferenceOutput {
  const ModelInferenceOutput({
    required this.text,
    required this.tokenCount,
  });

  final String text;
  final int tokenCount;
}

abstract interface class ModelRuntime {
  Future<void> load(ModelDescriptor descriptor);
  Future<void> unload();
  Future<bool> isLoaded(String modelId);
  Future<ModelInferenceOutput> infer(ModelInferenceInput input);
}
