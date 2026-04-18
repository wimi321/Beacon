import '../models/sos_models.dart';

abstract interface class MeshTransport {
  Future<int> broadcast(SosPacket packet);
}
