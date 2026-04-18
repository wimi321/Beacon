import '../contracts/model_runtime.dart';
import '../models/emergency_models.dart';
import '../models/evidence_models.dart';
import '../rag/retrieval_pipeline.dart';
import 'model_manager_service.dart';
import 'power_mode_service.dart';

class TriageService {
  TriageService({
    required RetrievalPipeline retrievalPipeline,
    required ModelManagerService modelManager,
    required PowerModeService powerModeService,
  })  : _retrievalPipeline = retrievalPipeline,
        _modelManager = modelManager,
        _powerModeService = powerModeService;

  final RetrievalPipeline _retrievalPipeline;
  final ModelManagerService _modelManager;
  final PowerModeService _powerModeService;

  static const Map<String, String> _languageNames = {
    'en': 'English',
    'zh-cn': 'Simplified Chinese',
    'zh-tw': 'Traditional Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'it': 'Italian',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'nl': 'Dutch',
    'pl': 'Polish',
    'uk': 'Ukrainian',
  };

  Future<EmergencyResponse> run(EmergencyRequest request) async {
    await _modelManager.ensureBootstrapped();

    final evidence = await _retrievalPipeline.retrieve(request);
    final profile = _powerModeService.profileFor(
      mode: request.powerMode,
      activeTier: _modelManager.activeModel.tier,
    );

    final groundingContext = _retrievalPipeline.buildGroundingContext(evidence);
    final systemPrompt = _buildSystemPrompt(locale: request.locale);
    final userPrompt = _buildUserPrompt(
      request: request,
      evidence: evidence,
      groundingContext: groundingContext,
    );

    final raw = await _modelManager.runtime.infer(
      ModelInferenceInput(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        profile: profile,
        sessionId: request.sessionId,
        resetContext: request.resetContext,
        imageBytes: request.imageBytes,
      ),
    );

    final steps = _parseSteps(raw.text);
    return EmergencyResponse(
      summary: steps.isEmpty ? raw.text.trim() : steps.first.instruction,
      steps: steps,
      knowledge: evidence.allEvidence,
      evidence: evidence,
      disclaimer: evidence.hasAuthoritativeEvidence
          ? _groundedDisclaimer(request.locale)
          : _limitedEvidenceDisclaimer(request.locale),
      usedProfile: profile,
      isKnowledgeBacked: evidence.hasAuthoritativeEvidence,
      guidanceMode: GuidanceMode.grounded,
      rawPrompt: request.includeRawPrompt ? userPrompt : null,
    );
  }

  String _buildSystemPrompt({required String locale}) {
    final normalizedLocale = _normalizeLocale(locale);
    final languageName = _languageNames[normalizedLocale] ??
        _languageNames[_baseLanguage(normalizedLocale)] ??
        'English';
    return [
      'You are Beacon, an offline survival and first-aid assistant.',
      'Respond strictly in $languageName ($locale).',
      if (normalizedLocale == 'ar')
        'Use natural right-to-left Arabic phrasing and avoid mixing English unless medically necessary.',
      'Treat each request as self-contained unless the same session explicitly continues.',
      'If the input says SESSION_RESET: true, discard any prior conversation state but keep the model warm.',
      'Only use the provided authoritative evidence.',
      'If authoritative evidence is missing or weak, you must still answer and clearly label the answer as limited-evidence guidance.',
      'Do not start the answer with generic caveats such as "AI generated" or "evidence is limited".',
      'Put actionable rescue guidance first; disclaimer text is handled separately by the app.',
      'For wilderness, conflict, radiation, biohazard, and cyber-failure incidents, order the answer as immediate survival actions, then forbidden actions, then when to evacuate or call for help.',
      'Do not invent medicine, dosage, invasive procedures, or diagnosis.',
      'Do not reuse canned wording across different incidents; tailor the answer to the latest symptoms, injury mechanism, and danger signs.',
      'Return 4 to 6 concise numbered rescue steps when grounded evidence exists, otherwise 3 to 5.',
      'Mention contraindications when the evidence lists them.',
    ].join(' ');
  }

  String _buildUserPrompt({
    required EmergencyRequest request,
    required EvidenceBundle evidence,
    required String groundingContext,
  }) {
    return [
      'USER_EMERGENCY: ${request.userText}',
      if (request.categoryHint != null)
        'CATEGORY_HINT: ${request.categoryHint}',
      'SESSION_ID: ${request.sessionId}',
      'SESSION_RESET: ${request.resetContext}',
      if (evidence.matchedCategories.isNotEmpty)
        'MATCHED_CATEGORIES: ${evidence.matchedCategories.join(', ')}',
      'EVIDENCE_CONFIDENCE: ${evidence.hasAuthoritativeEvidence ? 'authoritative' : 'limited'}',
      'AUTHORITATIVE_CONTEXT:\n$groundingContext',
      'OUTPUT_FORMAT:',
      '1. One-line condition summary.',
      '2. Numbered rescue steps with enough detail to act immediately.',
      '3. One line listing forbidden actions if any exist in the evidence.',
      '4. One escalation line telling user when to seek human help.',
      if (!evidence.hasAuthoritativeEvidence)
        '5. Keep the wording scenario-specific; do not prepend generic limited-evidence caveats.',
    ].join('\n\n');
  }

  String _normalizeLocale(String locale) {
    final trimmed = locale.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'en';
    }

    if (_languageNames.containsKey(trimmed)) {
      return trimmed;
    }

    if (trimmed == 'zh') {
      return 'zh-cn';
    }

    return trimmed;
  }

  String _baseLanguage(String locale) {
    final normalized = _normalizeLocale(locale);
    final separatorIndex = normalized.indexOf('-');
    if (separatorIndex == -1) {
      return normalized;
    }
    return normalized.substring(0, separatorIndex);
  }

  String _groundedDisclaimer(String locale) {
    final normalized = _normalizeLocale(locale);
    final base = _baseLanguage(normalized);

    switch (normalized) {
      case 'zh-cn':
      case 'zh':
        return 'AI 仅供断网绝境下自救参考，一旦恢复通信，请立刻联系专业急救人员。';
      case 'zh-tw':
        return 'AI 僅供斷網絕境下自救參考，一旦恢復通訊，請立刻聯絡專業急救人員。';
      case 'ja':
        return 'このAI案内は通信断絶時の自助用です。通信が回復したら直ちに専門の救急支援を要請してください。';
      case 'ko':
        return '이 AI 안내는 통신이 끊긴 극한 상황에서의 자가 구조 참고용입니다. 통신이 복구되면 즉시 전문 응급 구조를 요청하세요.';
      case 'ar':
        return 'هذا التوجيه من الذكاء الاصطناعي مخصص للمساعدة الذاتية عند انقطاع الاتصال. عند عودة الاتصال اطلب المساعدة الطبية المتخصصة فوراً.';
    }

    switch (base) {
      case 'es':
        return 'Esta guia de IA es solo para autoayuda sin conexion. En cuanto vuelva la comunicacion, contacta de inmediato a los servicios de emergencia profesionales.';
      case 'fr':
        return "Cette aide IA sert uniquement a l'auto-assistance hors ligne. Des que la communication revient, contactez immediatement les secours professionnels.";
      case 'de':
        return 'Diese KI-Hilfe dient nur zur Selbstrettung ohne Verbindung. Sobald Kommunikation moglich ist, sofort professionelle Notfallhilfe kontaktieren.';
      case 'pt':
        return 'Esta orientacao por IA serve apenas para autoajuda offline. Assim que a comunicacao voltar, acione imediatamente o socorro profissional.';
      case 'ru':
        return 'Эта подсказка ИИ предназначена только для самопомощи при отсутствии связи. Как только связь восстановится, немедленно обратитесь к профессиональным спасателям.';
      case 'hi':
        return 'यह AI मार्गदर्शन केवल संचार न होने की स्थिति में आत्मरक्षा हेतु है। जैसे ही संचार लौटे, तुरंत पेशेवर आपात सहायता लें।';
      case 'id':
        return 'Panduan AI ini hanya untuk bantuan mandiri saat offline. Segera hubungi bantuan darurat profesional saat komunikasi kembali pulih.';
      case 'it':
        return 'Questa guida AI serve solo per l autosoccorso offline. Appena torna la comunicazione, contatta subito i soccorsi professionali.';
      case 'tr':
        return 'Bu yapay zeka yonlendirmesi yalnizca baglanti yokken kendi kendine yardim icindir. Iletisim geri gelir gelmez profesyonel acil yardim isteyin.';
      case 'vi':
        return 'Huong dan AI nay chi dung cho tu cuu khi mat lien lac. Ngay khi lien lac duoc khoi phuc, hay lien he ho tro cap cuu chuyen nghiep.';
      case 'th':
        return 'คำแนะนำจาก AI นี้ใช้เพื่อการช่วยเหลือตนเองเมื่อขาดการสื่อสารเท่านั้น เมื่อสื่อสารได้อีกครั้งให้ติดต่อหน่วยฉุกเฉินทันที';
      case 'nl':
        return 'Deze AI-hulp is alleen bedoeld voor zelfredzaamheid zonder verbinding. Neem direct contact op met professionele hulp zodra communicatie terugkeert.';
      case 'pl':
        return 'Ta pomoc AI sluzy wylacznie do samoratunku bez lacznosci. Gdy tylko lacznosc wroci, natychmiast skontaktuj sie z profesjonalna pomoca ratunkowa.';
      case 'uk':
        return 'Ця підказка ШІ призначена лише для самодопомоги без зв’язку. Щойно зв’язок відновиться, негайно зверніться по професійну допомогу.';
      default:
        return 'This AI guidance is only for self-rescue during communication loss. Contact professional emergency responders immediately once communication is restored.';
    }
  }

  String _limitedEvidenceDisclaimer(String locale) {
    final normalized = _normalizeLocale(locale);
    final base = _baseLanguage(normalized);

    switch (normalized) {
      case 'zh-cn':
      case 'zh':
        return '当前回答已调用 AI 生成，但本地权威证据不足；请将其视为有限证据下的最佳努力建议，并在恢复通信后立刻联系专业急救人员。';
      case 'zh-tw':
        return '目前回答已呼叫 AI 生成，但本地權威證據不足；請將其視為有限證據下的最佳努力建議，並在恢復通訊後立刻聯絡專業急救人員。';
      case 'ja':
        return 'この回答はAIが生成していますが、手元の権威エビデンスは十分ではありません。限定的な根拠に基づく最善努力の案内として扱い、通信回復後は直ちに専門救助を要請してください。';
      case 'ko':
        return '이 답변은 AI가 생성했지만 로컬 권위 근거는 충분하지 않습니다. 제한된 근거에서 나온 최선의 안내로 보고, 통신이 복구되면 즉시 전문 구조를 요청하세요.';
      case 'ar':
        return 'تم إنشاء هذه الإجابة بواسطة الذكاء الاصطناعي، لكن الأدلة المرجعية المحلية غير كافية. تعامل معها كإرشاد بأفضل جهد مع أدلة محدودة، واطلب المساعدة المتخصصة فور عودة الاتصال.';
      default:
        switch (base) {
          case 'es':
            return 'Esta respuesta fue generada por IA, pero la evidencia local autorizada es limitada. Trátala como una guía de mejor esfuerzo y contacta a emergencias profesionales en cuanto vuelva la comunicación.';
          case 'fr':
            return "Cette reponse est generee par l'IA, mais les preuves locales fiables sont limitees. Traitez-la comme une aide au mieux de ses capacites et contactez les secours des que la communication revient.";
          default:
            return 'This answer was generated by AI, but local authoritative evidence is limited. Treat it as best-effort guidance and contact professional emergency responders as soon as communication is restored.';
        }
    }
  }

  List<TriageStep> _parseSteps(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final numbered = <TriageStep>[];
    var order = 1;
    for (final line in lines) {
      final match = RegExp(r'^(?:\d+[.)、\-:]\s*)(.+)$').firstMatch(line);
      if (match != null) {
        final instruction = match.group(1)!.trim();
        final stepNumber = order;
        numbered.add(
          TriageStep(
            order: stepNumber,
            title: 'Step $stepNumber',
            instruction: instruction,
            isCritical: stepNumber <= 3,
          ),
        );
        order++;
      }
    }

    if (numbered.isNotEmpty) {
      return numbered;
    }

    return [
      TriageStep(
        order: 1,
        title: 'Emergency Guidance',
        instruction: text.trim(),
        isCritical: true,
      ),
    ];
  }
}
