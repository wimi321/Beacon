import '../contracts/model_downloader.dart';
import '../contracts/model_runtime.dart';
import '../models/model_models.dart';

class ModelManagerService {
  ModelManagerService({
    required ModelRuntime runtime,
    required ModelDownloader downloader,
    required ModelDescriptor bootstrapModel,
  })  : _runtime = runtime,
        _downloader = downloader,
        _activeModel = bootstrapModel;

  final ModelRuntime _runtime;
  final ModelDownloader _downloader;
  ModelDescriptor _activeModel;

  ModelDescriptor get activeModel => _activeModel;
  ModelRuntime get runtime => _runtime;

  Future<void> ensureBootstrapped() async {
    final loaded = await _runtime.isLoaded(_activeModel.id);
    if (!loaded) {
      await _runtime.load(_activeModel);
    }
  }

  Stream<DownloadProgress> downloadModel(
    Uri uri,
    String outputPath, {
    int? resumeFrom,
  }) {
    return _downloader.download(uri, outputPath, resumeFrom: resumeFrom);
  }

  Future<void> hotSwap(ModelDescriptor descriptor) async {
    if (descriptor.id == _activeModel.id) {
      return;
    }

    await _runtime.unload();
    await _runtime.load(descriptor);
    _activeModel = descriptor;
  }
}
