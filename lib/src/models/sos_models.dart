class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}

class SosPacket {
  const SosPacket({
    required this.senderId,
    required this.timestamp,
    required this.location,
    required this.brief,
    required this.hopCount,
    required this.maxHops,
    required this.ttl,
  });

  final String senderId;
  final DateTime timestamp;
  final GeoPoint location;
  final String brief;
  final int hopCount;
  final int maxHops;
  final Duration ttl;

  bool get canRelay => hopCount < maxHops;

  SosPacket relayed() {
    return SosPacket(
      senderId: senderId,
      timestamp: timestamp,
      location: location,
      brief: brief,
      hopCount: hopCount + 1,
      maxHops: maxHops,
      ttl: ttl,
    );
  }
}

class SosBroadcastResult {
  const SosBroadcastResult({
    required this.packet,
    required this.deliveredToPeers,
  });

  final SosPacket packet;
  final int deliveredToPeers;
}
