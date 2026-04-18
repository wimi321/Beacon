import '../config/backend_config.dart';
import '../contracts/knowledge_store.dart';
import '../contracts/mesh_transport.dart';
import '../contracts/model_downloader.dart';
import '../contracts/model_runtime.dart';
import '../models/emergency_models.dart';
import '../models/model_models.dart';
import '../models/sos_models.dart';
import '../rag/retrieval_pipeline.dart';
import '../services/model_manager_service.dart';
import '../services/power_mode_service.dart';
import '../services/sos_service.dart';
import '../services/triage_service.dart';

class BeaconBackend {
  BeaconBackend({
    required KnowledgeStore knowledgeStore,
    required ModelRuntime modelRuntime,
    required ModelDownloader modelDownloader,
    required MeshTransport meshTransport,
    required ModelDescriptor bootstrapModel,
    BeaconBackendConfig? config,
  }) : config = config ?? BeaconBackendConfig.doomsdayDefaults(),
       powerModeService = PowerModeService(),
       modelManager = ModelManagerService(
         runtime: modelRuntime,
         downloader: modelDownloader,
         bootstrapModel: bootstrapModel,
       ),
       retrievalPipeline = RetrievalPipeline(
         knowledgeStore: knowledgeStore,
         config: config ?? BeaconBackendConfig.doomsdayDefaults(),
       ),
       sosService = SosService(
         meshTransport: meshTransport,
         config: config ?? BeaconBackendConfig.doomsdayDefaults(),
       ) {
    triageService = TriageService(
      retrievalPipeline: retrievalPipeline,
      modelManager: modelManager,
      powerModeService: powerModeService,
    );
  }

  final BeaconBackendConfig config;
  final PowerModeService powerModeService;
  final ModelManagerService modelManager;
  final RetrievalPipeline retrievalPipeline;
  late final TriageService triageService;
  final SosService sosService;

  Future<EmergencyResponse> triage(EmergencyRequest request) {
    powerModeService.setMode(request.powerMode);
    return triageService.run(request);
  }

  Future<SosBroadcastResult> broadcastSos({
    required String senderId,
    required GeoPoint location,
    required String brief,
  }) {
    return sosService.broadcast(
      senderId: senderId,
      location: location,
      brief: brief,
    );
  }
}
