import 'dart:typed_data';

import 'evidence_models.dart';
import 'knowledge_models.dart';
import 'model_models.dart';

class EmergencyRequest {
  const EmergencyRequest({
    required this.userText,
    this.imageBytes,
    this.locale = 'zh-CN',
    this.categoryHint,
    this.powerMode = PowerMode.normal,
    this.sessionId = 'session-default',
    this.resetContext = false,
    this.includeRawPrompt = false,
  });

  final String userText;
  final Uint8List? imageBytes;
  final String locale;
  final String? categoryHint;
  final PowerMode powerMode;
  final String sessionId;
  final bool resetContext;
  final bool includeRawPrompt;
}

class TriageStep {
  const TriageStep({
    required this.order,
    required this.title,
    required this.instruction,
    this.isCritical = false,
  });

  final int order;
  final String title;
  final String instruction;
  final bool isCritical;
}

class EmergencyResponse {
  const EmergencyResponse({
    required this.summary,
    required this.steps,
    required this.knowledge,
    required this.evidence,
    required this.disclaimer,
    required this.usedProfile,
    required this.isKnowledgeBacked,
    required this.guidanceMode,
    this.rawPrompt,
  });

  final String summary;
  final List<TriageStep> steps;
  final List<RetrievedKnowledge> knowledge;
  final EvidenceBundle evidence;
  final String disclaimer;
  final ModelProfile usedProfile;
  final bool isKnowledgeBacked;
  final GuidanceMode guidanceMode;
  final String? rawPrompt;
}
