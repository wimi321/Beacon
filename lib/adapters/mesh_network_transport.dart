import '../src/contracts/mesh_transport.dart';
import '../src/models/sos_models.dart';

class MeshNetworkTransport implements MeshTransport {
  @override
  Future<int> broadcast(SosPacket packet) async {
    throw UnimplementedError(
      'Use flutter_mesh_network to broadcast and relay SOS packets here.',
    );
  }
}
