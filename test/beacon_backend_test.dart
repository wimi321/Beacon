import 'package:beacon_backend/beacon_backend.dart';
import 'package:test/test.dart';

void main() {
  test('bootstrap knowledge ships a materially sized offline bundle', () {
    final entries = BootstrapModels.emergencySeedKnowledge();
    expect(entries.length, greaterThanOrEqualTo(1000));
    expect(entries.first.sourceUrl, isNotEmpty);
    expect(
      entries.any((entry) => entry.source.contains('FM 21-76')),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.source.contains('MSD Manual')),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.id == 'tourniquet-placement'),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.id == 'opioid-overdose-naloxone'),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.id == 'hypoglycemia-15-15'),
      isTrue,
    );
    expect(
      entries.any(
        (entry) =>
            entry.source.contains('American Red Cross') ||
            entry.source.contains('SAMHSA') ||
            entry.source.contains('NIDDK'),
      ),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.source.contains('National Park Service')),
      isTrue,
    );
    expect(
      entries.any(
          (entry) => entry.source.contains('National Weather Service / NOAA')),
      isTrue,
    );
    expect(
      entries.any((entry) => entry.source.contains('Ready.gov')),
      isTrue,
    );
  });

  test('knowledge store expands wilderness and crisis survival queries',
      () async {
    final store = InMemoryKnowledgeStore();
    await store.upsertAll([
      const KnowledgeEntry(
        id: 'survival-night',
        title: '没信号又快天黑时先稳住保温和方位',
        summary: '通信中断加临近天黑时，先把自己留在更容易活过夜的位置。',
        steps: ['先停下评估体温、水和电量。'],
        contraindications: ['不要盲目赶路'],
        escalation: '若天气恶化，立刻待援。',
        tags: ['survival_field', '断联', '天黑', 'no signal'],
        aliases: ['山里没信号怎么办'],
        source: 'National Park Service: Wilderness Travel Basics',
        priority: 9,
      ),
      const KnowledgeEntry(
        id: 'radiation-fallout',
        title: '核爆或放射性尘降时先进去待住听通知',
        summary: '先进入厚实建筑内部，减少外暴露。',
        steps: ['立刻进入坚固建筑。'],
        contraindications: ['不要继续停留在户外'],
        escalation: '建筑失效时尽快转移到更厚实掩体。',
        tags: ['crisis_radiation', '核爆', 'fallout'],
        aliases: ['核爆后怎么办'],
        source: 'Ready.gov: Radiation Emergencies',
        priority: 10,
      ),
      const KnowledgeEntry(
        id: 'cyber-outage',
        title: '网络或 AI 攻击怀疑时立刻切离线保核心功能',
        summary: '先保留通信、电量和可信信息源。',
        steps: ['断开可疑网络连接。'],
        contraindications: ['不要点击未知链接'],
        escalation: '若已影响基础设施，转入长期停电停网方案。',
        tags: ['crisis_cyber', 'ai攻击', '停电', '断网'],
        aliases: ['AI攻击导致停电断网怎么办'],
        source: 'Ready.gov: Cybersecurity',
        priority: 8,
      ),
    ]);

    final wilderness = await store.search(query: '山里没信号天快黑了怎么办', limit: 1);
    final radiation = await store.search(query: '核爆后外面可能有灰尘怎么办', limit: 1);
    final cyber = await store.search(query: 'AI攻击导致停电断网，现在先做什么', limit: 1);

    expect(wilderness.first.entry.id, 'survival-night');
    expect(radiation.first.entry.id, 'radiation-fallout');
    expect(cyber.first.entry.id, 'cyber-outage');
  });

  test('knowledge store maps colloquial chest pain and scald queries to the right first-aid cards',
      () async {
    final store = InMemoryKnowledgeStore();
    await store.upsertAll([
      const KnowledgeEntry(
        id: 'heart-attack',
        title: '疑似心梗的处置',
        summary: '胸痛伴冷汗和放射痛时，先按心梗处理。',
        steps: ['立即停止活动并取最易呼吸姿势。'],
        contraindications: ['不要继续走动或负重'],
        escalation: '尽快联系急救。',
        tags: ['heart attack', 'chest pain', 'cardiac'],
        aliases: ['胸痛冒冷汗', '左臂放射痛'],
        source: 'MedlinePlus: Heart attack first aid',
        priority: 10,
      ),
      const KnowledgeEntry(
        id: 'burns',
        title: '热力烧伤与烫伤处置',
        summary: '先持续凉水降温并保护创面。',
        steps: ['立即用流动凉水冲洗烧伤处。'],
        contraindications: ['不要涂牙膏或直接敷冰'],
        escalation: '面积大或在面部会阴时立刻转运。',
        tags: ['burn', 'burns', 'scald'],
        aliases: ['热油烫伤', '烫到手臂'],
        source: 'NHS: Burns and scalds',
        priority: 10,
      ),
    ]);

    final chestPain = await store.search(
      query: '胸口很痛，冒冷汗，左臂也痛，怎么先保命',
      limit: 1,
    );
    final burns = await store.search(
      query: '热油烫到手臂一大片，现在该怎么处理',
      limit: 1,
    );

    expect(chestPain.first.entry.id, 'heart-attack');
    expect(burns.first.entry.id, 'burns');
  });

  test('triage uses direct evidence hits and doomsday profile', () async {
    final knowledgeStore = InMemoryKnowledgeStore();
    await knowledgeStore.upsertAll([
      const KnowledgeEntry(
        id: 'bleeding-1',
        title: '大出血处理',
        summary: '持续性大出血先压迫止血。',
        steps: [
          '直接压迫出血点。',
          '持续加压并抬高伤肢。',
          '必要时使用止血带并记录时间。',
        ],
        contraindications: ['不要频繁松开检查'],
        escalation: '尽快联系急救人员并安排转运。',
        tags: ['出血', '止血', 'tourniquet'],
        aliases: ['大出血', 'bleeding'],
        source: 'FM 21-76',
        priority: 10,
      ),
    ]);

    final backend = BeaconBackend(
      knowledgeStore: knowledgeStore,
      modelRuntime: _FakeRuntime(),
      modelDownloader: _FakeDownloader(),
      meshTransport: _FakeMeshTransport(),
      bootstrapModel: const ModelDescriptor(
        id: 'gemma-e2b',
        tier: ModelTier.e2b,
        localPath: '/models/gemma-e2b.litertlm',
        isMultimodal: true,
        sizeBytes: 1024,
        sha256: 'abc',
      ),
    );

    final response = await backend.triage(
      const EmergencyRequest(
        userText: '患者手臂大出血，怎么先救命？',
        categoryHint: '大出血',
        powerMode: PowerMode.doomsday,
      ),
    );

    expect(response.isKnowledgeBacked, isTrue);
    expect(response.guidanceMode, GuidanceMode.grounded);
    expect(response.evidence.authoritative, isNotEmpty);
    expect(response.usedProfile.name, ModelProfile.e2bSaver.name);
    expect(response.steps, isNotEmpty);
  });

  test('triage still calls AI without authoritative evidence', () async {
    final runtime = _FakeRuntime();
    final backend = BeaconBackend(
      knowledgeStore: InMemoryKnowledgeStore(),
      modelRuntime: runtime,
      modelDownloader: _FakeDownloader(),
      meshTransport: _FakeMeshTransport(),
      bootstrapModel: const ModelDescriptor(
        id: 'gemma-e2b',
        tier: ModelTier.e2b,
        localPath: '/models/gemma-e2b.litertlm',
        isMultimodal: true,
        sizeBytes: 1024,
        sha256: 'abc',
      ),
    );

    final response = await backend.triage(
      const EmergencyRequest(
        userText: '感觉不太对，但是说不清哪里受伤。',
        locale: 'en',
      ),
    );

    expect(runtime.lastInput, isNotNull);
    expect(response.guidanceMode, GuidanceMode.grounded);
    expect(response.isKnowledgeBacked, isFalse);
    expect(response.disclaimer, contains('AI'));
    expect(response.disclaimer, contains('limited'));
  });

  test('triage system prompt pins model output language from locale', () async {
    final runtime = _FakeRuntime();
    final knowledgeStore = InMemoryKnowledgeStore();
    await knowledgeStore.upsertAll([
      const KnowledgeEntry(
        id: 'fire-1',
        title: 'Fire survival basics',
        summary: 'Stay low and avoid smoke inhalation.',
        steps: [
          'Stay low to the ground.',
          'Seal gaps if the door is hot.',
          'Signal for help near a window.',
        ],
        contraindications: ['Do not run upright through smoke'],
        escalation:
            'Seek emergency responders as soon as communication returns.',
        tags: ['fire', 'smoke'],
        aliases: ['smoke inhalation', 'trapped in fire'],
        source: 'NFPA Fire Survival',
        priority: 10,
      ),
    ]);
    final backend = BeaconBackend(
      knowledgeStore: knowledgeStore,
      modelRuntime: runtime,
      modelDownloader: _FakeDownloader(),
      meshTransport: _FakeMeshTransport(),
      bootstrapModel: const ModelDescriptor(
        id: 'gemma-e2b',
        tier: ModelTier.e2b,
        localPath: '/models/gemma-e2b.litertlm',
        isMultimodal: true,
        sizeBytes: 1024,
        sha256: 'abc',
      ),
    );

    await backend.triage(
      const EmergencyRequest(
        userText: 'Need help with smoke inhalation.',
        categoryHint: 'fire',
        locale: 'ja',
      ),
    );

    expect(runtime.lastInput, isNotNull);
    expect(runtime.lastInput!.systemPrompt, contains('Japanese'));
    expect(runtime.lastInput!.systemPrompt, contains('ja'));
  });

  test(
      'triage reset starts a new logical session without unloading the hot model',
      () async {
    final runtime = _FakeRuntime();
    final backend = BeaconBackend(
      knowledgeStore: InMemoryKnowledgeStore(),
      modelRuntime: runtime,
      modelDownloader: _FakeDownloader(),
      meshTransport: _FakeMeshTransport(),
      bootstrapModel: const ModelDescriptor(
        id: 'gemma-e2b',
        tier: ModelTier.e2b,
        localPath: '/models/gemma-e2b.litertlm',
        isMultimodal: true,
        sizeBytes: 1024,
        sha256: 'abc',
      ),
    );

    await backend.triage(
      const EmergencyRequest(
        userText: 'First session request.',
        locale: 'en',
        sessionId: 'session-a',
      ),
    );

    await backend.triage(
      const EmergencyRequest(
        userText: 'Second session after clear.',
        locale: 'en',
        sessionId: 'session-b',
        resetContext: true,
      ),
    );

    expect(runtime.loadCount, 1);
    expect(runtime.unloadCount, 0);
    expect(runtime.lastInput, isNotNull);
    expect(runtime.lastInput!.sessionId, 'session-b');
    expect(runtime.lastInput!.resetContext, isTrue);
    expect(runtime.lastInput!.userPrompt, contains('SESSION_RESET: true'));
  });

  test('sos packet broadcasts with hop metadata', () async {
    final backend = BeaconBackend(
      knowledgeStore: InMemoryKnowledgeStore(),
      modelRuntime: _FakeRuntime(),
      modelDownloader: _FakeDownloader(),
      meshTransport: _FakeMeshTransport(),
      bootstrapModel: const ModelDescriptor(
        id: 'gemma-e2b',
        tier: ModelTier.e2b,
        localPath: '/models/gemma-e2b.litertlm',
        isMultimodal: true,
        sizeBytes: 1024,
        sha256: 'abc',
      ),
    );

    final result = await backend.broadcastSos(
      senderId: 'node-a',
      location: const GeoPoint(latitude: 30.2741, longitude: 120.1551),
      brief: '腿部开放性骨折，意识清醒，需要转运。',
    );

    expect(result.packet.canRelay, isTrue);
    expect(result.deliveredToPeers, 2);
  });
}

class _FakeRuntime implements ModelRuntime {
  String? _loadedModelId;
  ModelInferenceInput? lastInput;
  int loadCount = 0;
  int unloadCount = 0;

  @override
  Future<ModelInferenceOutput> infer(ModelInferenceInput input) async {
    lastInput = input;
    return const ModelInferenceOutput(
      text: '1. 先直接压迫出血点。\n2. 用干净布料持续加压。\n3. 若无法止血再使用止血带并记录时间。',
      tokenCount: 42,
    );
  }

  @override
  Future<bool> isLoaded(String modelId) async => _loadedModelId == modelId;

  @override
  Future<void> load(ModelDescriptor descriptor) async {
    _loadedModelId = descriptor.id;
    loadCount++;
  }

  @override
  Future<void> unload() async {
    _loadedModelId = null;
    unloadCount++;
  }
}

class _FakeDownloader implements ModelDownloader {
  @override
  Stream<DownloadProgress> download(Uri uri, String outputPath,
      {int? resumeFrom}) {
    return Stream<DownloadProgress>.fromIterable([
      DownloadProgress(
          receivedBytes: 50, totalBytes: 100, isResumed: resumeFrom != null),
      DownloadProgress(
          receivedBytes: 100, totalBytes: 100, isResumed: resumeFrom != null),
    ]);
  }
}

class _FakeMeshTransport implements MeshTransport {
  @override
  Future<int> broadcast(SosPacket packet) async => 2;
}
