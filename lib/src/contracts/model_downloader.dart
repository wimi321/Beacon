import '../models/model_models.dart';

abstract interface class ModelDownloader {
  Stream<DownloadProgress> download(
    Uri uri,
    String outputPath, {
    int? resumeFrom,
  });
}
