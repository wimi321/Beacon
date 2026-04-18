import '../src/contracts/model_runtime.dart';
import '../src/models/model_models.dart';

class LiteRtModelRuntime implements ModelRuntime {
  @override
  Future<ModelInferenceOutput> infer(ModelInferenceInput input) async {
    throw UnimplementedError(
      'Connect flutter_litert here and map ModelInferenceInput to Gemma 4 multimodal inference.',
    );
  }

  @override
  Future<bool> isLoaded(String modelId) async {
    throw UnimplementedError(
      'Track the active flutter_litert model instance and compare it here.',
    );
  }

  @override
  Future<void> load(ModelDescriptor descriptor) async {
    throw UnimplementedError(
      'Open the .litertlm file, initialize accelerator settings, and warm up the model here.',
    );
  }

  @override
  Future<void> unload() async {
    throw UnimplementedError(
      'Release the active flutter_litert session and free native memory here.',
    );
  }
}
