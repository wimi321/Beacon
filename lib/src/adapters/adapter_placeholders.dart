import '../contracts/knowledge_store.dart';
import '../contracts/mesh_transport.dart';
import '../contracts/model_downloader.dart';
import '../contracts/model_runtime.dart';

typedef LiteRtModelRuntimeFactory = ModelRuntime Function();
typedef LocalKnowledgeStoreFactory = KnowledgeStore Function();
typedef MeshTransportFactory = MeshTransport Function();
typedef ResumableDownloaderFactory = ModelDownloader Function();
