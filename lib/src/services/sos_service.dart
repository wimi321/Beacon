import '../config/backend_config.dart';
import '../contracts/mesh_transport.dart';
import '../models/sos_models.dart';

class SosService {
  SosService({
    required MeshTransport meshTransport,
    required BeaconBackendConfig config,
  })  : _meshTransport = meshTransport,
        _config = config;

  final MeshTransport _meshTransport;
  final BeaconBackendConfig _config;

  Future<SosBroadcastResult> broadcast({
    required String senderId,
    required GeoPoint location,
    required String brief,
    int? maxHops,
    Duration? ttl,
  }) async {
    final packet = SosPacket(
      senderId: senderId,
      timestamp: DateTime.now().toUtc(),
      location: location,
      brief: brief,
      hopCount: 0,
      maxHops: maxHops ?? _config.defaultMeshHopLimit,
      ttl: ttl ?? _config.defaultMeshTtl,
    );

    final delivered = await _meshTransport.broadcast(packet);
    return SosBroadcastResult(packet: packet, deliveredToPeers: delivered);
  }
}
