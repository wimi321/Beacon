import '../src/contracts/model_downloader.dart';
import '../src/models/model_models.dart';

class ResumableHttpDownloader implements ModelDownloader {
  @override
  Stream<DownloadProgress> download(
    Uri uri,
    String outputPath, {
    int? resumeFrom,
  }) {
    throw UnimplementedError(
      'Implement HTTP range requests, temp-file checkpoints, and progress streaming here.',
    );
  }
}
