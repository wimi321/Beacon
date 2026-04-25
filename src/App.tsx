import { useEffect, useMemo, useRef, useState } from 'react';
import type { CSSProperties, FormEvent, TouchEvent as ReactTouchEvent } from 'react';
import {
  Camera as CameraIcon,
  Download,
  LoaderCircle,
  Settings,
  ShieldCheck,
  Zap,
} from 'lucide-react';
import { App as CapacitorApp } from '@capacitor/app';
import { Camera as CapacitorCamera, CameraResultType, CameraSource } from '@capacitor/camera';
import { Capacitor } from '@capacitor/core';
import { Network } from '@capacitor/network';
import { getBeaconBridge } from './lib/runtime';
import {
  attachTriageSession,
  consumeTriageSessionReset,
  createTriageSessionState,
  resetTriageSessionState,
} from './lib/session';
import type {
  BatteryStatus,
  BeaconMessage,
  ModelDownloadStatus,
  ModelDescriptor,
  PowerMode,
  TriageResponse,
} from './lib/types';
import { useI18n } from './i18n';
import { NavBar } from './components/NavBar';
import { LanguageSwitcher } from './components/LanguageSwitcher';
import { MarkdownMessage } from './components/MarkdownMessage';
import { useHashRouter } from './lib/useHashRouter';
import type { BeaconBridge } from './lib/beaconBridge';
import {
  buildDisplayResponseText,
  formatModelTextForDisplay,
  hasMeaningfulModelText,
} from './lib/modelText';
import { resolveLocaleCode, translateMessage } from './i18n/translate';
import { CANONICAL_SCENARIO_HINTS } from './lib/scenarioHints';

function resolveBatteryWarning(
  status: BatteryStatus,
  localize: (key: Parameters<ReturnType<typeof useI18n>['t']>[0], params?: Record<string, string | number>) => string,
): string | undefined {
  if (status.warningCode === 'battery.low_power_emergency') {
    return localize('warning.battery_low');
  }

  return status.warning;
}

function formatModelSizeLabel(
  model: ModelDescriptor,
  localize: ReturnType<typeof useI18n>['t'],
): string {
  if (model.id === 'gemma-4-e2b' || model.tier === 'e2b') {
    return localize('model.size_e2b');
  }
  if (model.id === 'gemma-4-e4b' || model.tier === 'e4b') {
    return localize('model.size_e4b');
  }
  return model.sizeLabel;
}

function chooseRecommendedDownloadModel(models: ModelDescriptor[]): ModelDescriptor | null {
  return models.find((model) => model.id === 'gemma-4-e2b')
    ?? models[0]
    ?? null;
}

function chooseAlternateDownloadModel(
  models: ModelDescriptor[],
  recommendedModelId?: string,
): ModelDescriptor | null {
  return models.find((model) => model.id === 'gemma-4-e4b' && model.id !== recommendedModelId)
    ?? models.find((model) => model.id !== recommendedModelId)
    ?? null;
}

function createFallbackDownloadCatalog(): ModelDescriptor[] {
  return [
    {
      id: 'gemma-4-e2b',
      tier: 'e2b',
      name: 'Gemma 4 E2B',
      localPath: 'models/gemma-4-E2B-it.litertlm',
      sizeLabel: '2B / Survival Baseline',
      isLoaded: false,
      isDownloaded: false,
      downloadStatus: 'not_downloaded',
      artifactFormat: 'litertlm',
      runtimeStack: 'litert-lm-c-api',
      preferredBackend: 'auto-real',
      capabilityClass: 'supported',
      supportedDeviceClass: 'unknown',
      supportsImageInput: true,
      supportsVision: true,
      defaultProfileName: 'gemma-4-e2b-balanced',
      recommendedFor: 'Default offline triage on most phones.',
      acceleratorHints: ['gpu', 'cpu'],
      isBundled: false,
      sizeBytes: 2_583_085_056,
    },
    {
      id: 'gemma-4-e4b',
      tier: 'e4b',
      name: 'Gemma 4 E4B',
      localPath: 'models/gemma-4-E4B-it.litertlm',
      sizeLabel: '4B / High Precision',
      isLoaded: false,
      isDownloaded: false,
      downloadStatus: 'not_downloaded',
      artifactFormat: 'litertlm',
      runtimeStack: 'litert-lm-c-api',
      preferredBackend: 'auto-real',
      capabilityClass: 'supported',
      supportedDeviceClass: 'unknown',
      supportsImageInput: true,
      supportsVision: true,
      defaultProfileName: 'gemma-4-e4b-expert',
      recommendedFor: 'Higher precision when thermal and battery headroom allow.',
      acceleratorHints: ['gpu', 'cpu'],
      isBundled: false,
      sizeBytes: 3_654_467_584,
    },
  ];
}

function extractErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message.trim();
  }
  if (typeof error === 'string' && error.trim().length > 0) {
    return error.trim();
  }
  if (error && typeof error === 'object') {
    const maybeMessage = 'message' in error ? error.message : undefined;
    if (typeof maybeMessage === 'string' && maybeMessage.trim().length > 0) {
      return maybeMessage.trim();
    }
  }
  return '';
}

function isCancelledCameraCapture(error: unknown): boolean {
  const message = extractErrorMessage(error).toLowerCase();
  return message.includes('cancel');
}

function isCameraPermissionDenied(error: unknown): boolean {
  const message = extractErrorMessage(error).toLowerCase();
  return message.includes('permission')
    || message.includes('denied')
    || message.includes('not authorized')
    || message.includes('access');
}

function formatDownloadEta(startTime: number | undefined, fraction: number): string {
  if (!startTime || fraction <= 0) return '';
  const elapsed = (Date.now() - startTime) / 1000;
  if (elapsed < 3 || fraction < 0.01) return '';
  const remaining = (elapsed / fraction) * (1 - fraction);
  if (remaining < 60) return ` (~${Math.ceil(remaining)}s)`;
  return ` (~${Math.ceil(remaining / 60)}min)`;
}

function shouldStopAutoModelRetry(message: string): boolean {
  const normalized = message.toLowerCase();
  return normalized.includes('below the current gemma 4 e2b ios baseline')
    || normalized.includes('内存低于 6gb')
    || normalized.includes('litert-lm failed to initialize gemma 4 on this ios runtime');
}

const MODEL_LOW_MEMORY_MESSAGE: Record<string, string> = {
  en: 'This iPhone has under 6 GB RAM, so Gemma 4 E2B cannot start locally on this device. Use a newer iPhone or Android flagship.',
  'zh-CN': '当前这台 iPhone 内存低于 6GB，无法在本机启动 Gemma 4 E2B。请改用更新的 iPhone 或 Android 旗舰机。',
  'zh-TW': '目前這台 iPhone 記憶體低於 6GB，無法在本機啟動 Gemma 4 E2B。請改用更新的 iPhone 或 Android 旗艦機。',
  ja: 'この iPhone は 6GB 未満のメモリのため、Gemma 4 E2B を端末上で起動できません。より新しい iPhone か Android 端末を使用してください。',
  ko: '이 iPhone은 메모리가 6GB 미만이라 Gemma 4 E2B를 기기에서 실행할 수 없습니다. 더 최신 iPhone 또는 Android 기기를 사용하세요.',
  es: 'Este iPhone tiene menos de 6 GB de RAM, por lo que Gemma 4 E2B no puede iniciarse localmente. Usa un iPhone mas nuevo o un Android de gama alta.',
  fr: 'Cet iPhone a moins de 6 Go de RAM, donc Gemma 4 E2B ne peut pas demarrer localement. Utilise un iPhone plus recent ou un Android haut de gamme.',
  de: 'Dieses iPhone hat weniger als 6 GB RAM, deshalb kann Gemma 4 E2B nicht lokal gestartet werden. Nutze ein neueres iPhone oder ein Android-Flaggschiff.',
  pt: 'Este iPhone tem menos de 6 GB de RAM, entao o Gemma 4 E2B nao pode iniciar localmente. Use um iPhone mais novo ou um Android topo de linha.',
  ru: 'На этом iPhone меньше 6 ГБ ОЗУ, поэтому Gemma 4 E2B не может запуститься локально. Используй более новый iPhone или флагманский Android.',
  ar: 'يحتوي هذا iPhone على أقل من 6 جيجابايت من الذاكرة، لذلك لا يمكن تشغيل Gemma 4 E2B محليًا. استخدم iPhone أحدث أو هاتف Android رائد.',
  hi: 'इस iPhone में 6 GB से कम RAM है, इसलिए Gemma 4 E2B लोकल रूप से शुरू नहीं हो सकता। नया iPhone या फ्लैगशिप Android इस्तेमाल करें।',
  id: 'iPhone ini memiliki RAM kurang dari 6 GB, jadi Gemma 4 E2B tidak bisa berjalan secara lokal. Gunakan iPhone yang lebih baru atau Android flagship.',
  it: 'Questo iPhone ha meno di 6 GB di RAM, quindi Gemma 4 E2B non puo avviarsi in locale. Usa un iPhone piu recente o un Android di fascia alta.',
  tr: 'Bu iPhone 6 GB altinda belleğe sahip, bu nedenle Gemma 4 E2B cihazda yerel olarak baslayamaz. Daha yeni bir iPhone veya ust duzey bir Android kullan.',
  vi: 'iPhone nay co duoi 6 GB RAM, vi vay Gemma 4 E2B khong the chay cuc bo. Hay dung iPhone moi hon hoac Android cao cap.',
  th: 'iPhone เครื่องนี้มี RAM น้อยกว่า 6 GB จึงไม่สามารถเริ่ม Gemma 4 E2B บนเครื่องได้ ใช้ iPhone ที่ใหม่กว่าหรือ Android ระดับเรือธงแทน',
  nl: 'Deze iPhone heeft minder dan 6 GB RAM, waardoor Gemma 4 E2B niet lokaal kan starten. Gebruik een nieuwere iPhone of een Android-vlaggenschip.',
  pl: 'Ten iPhone ma mniej niz 6 GB RAM, dlatego Gemma 4 E2B nie uruchomi sie lokalnie. Uzyj nowszego iPhone a albo flagowego Androida.',
  uk: 'Цей iPhone має менше ніж 6 ГБ пам яті, тому Gemma 4 E2B не може запуститися локально. Використай новіший iPhone або флагманський Android.',
};

const MODEL_RUNTIME_INIT_MESSAGE: Record<string, string> = {
  en: 'LiteRT-LM could not start Gemma 4 E2B on this iPhone runtime. Automatic retries have been paused; retry manually after changing device or runtime conditions.',
  'zh-CN': '这台 iPhone 上的 LiteRT-LM 运行时未能启动 Gemma 4 E2B，本次已停止自动重试。请手动重试，或更换受支持设备继续验证。',
  'zh-TW': '這台 iPhone 上的 LiteRT-LM 執行時未能啟動 Gemma 4 E2B，本次已停止自動重試。請手動重試，或更換受支援裝置繼續驗證。',
  ja: 'この iPhone の LiteRT-LM ランタイムでは Gemma 4 E2B を起動できませんでした。自動再試行は停止したため、端末や実行条件を変えて手動で再試行してください。',
  ko: '이 iPhone 런타임에서는 LiteRT-LM이 Gemma 4 E2B를 시작하지 못했습니다. 자동 재시도는 중지되었으니 기기나 실행 조건을 바꾼 뒤 수동으로 다시 시도하세요.',
  es: 'LiteRT-LM no pudo iniciar Gemma 4 E2B en este runtime de iPhone. Los reintentos automaticos se pausaron; vuelve a intentarlo manualmente tras cambiar el dispositivo o las condiciones.',
  fr: 'LiteRT-LM n a pas pu lancer Gemma 4 E2B sur cet iPhone. Les nouvelles tentatives automatiques sont en pause ; reessaie manuellement apres avoir change l appareil ou les conditions.',
  de: 'LiteRT-LM konnte Gemma 4 E2B auf diesem iPhone nicht starten. Automatische Wiederholungen wurden pausiert; versuche es nach einem Geraete- oder Laufzeitwechsel manuell erneut.',
  pt: 'O LiteRT-LM nao conseguiu iniciar o Gemma 4 E2B neste iPhone. As novas tentativas automaticas foram pausadas; tente manualmente apos mudar o aparelho ou as condicoes.',
  ru: 'LiteRT-LM не смог запустить Gemma 4 E2B на этом iPhone. Автоповторы остановлены; повтори попытку вручную после смены устройства или условий выполнения.',
  ar: 'تعذر على LiteRT-LM تشغيل Gemma 4 E2B على هذا الـ iPhone. تم إيقاف إعادة المحاولة التلقائية؛ أعد المحاولة يدويًا بعد تغيير الجهاز أو ظروف التشغيل.',
  hi: 'LiteRT-LM इस iPhone पर Gemma 4 E2B शुरू नहीं कर पाया। ऑटो रीट्राई रोक दिए गए हैं; डिवाइस या रनटाइम स्थिति बदलकर मैन्युअली फिर कोशिश करें।',
  id: 'LiteRT-LM tidak bisa memulai Gemma 4 E2B di iPhone ini. Percobaan ulang otomatis dihentikan; coba lagi secara manual setelah mengganti perangkat atau kondisi runtime.',
  it: 'LiteRT-LM non e riuscito ad avviare Gemma 4 E2B su questo iPhone. I tentativi automatici sono stati sospesi; riprova manualmente dopo aver cambiato dispositivo o condizioni di runtime.',
  tr: 'LiteRT-LM bu iPhone uzerinde Gemma 4 E2B yi baslatamadi. Otomatik yeniden denemeler durduruldu; cihazi veya calisma kosullarini degistirdikten sonra elle tekrar dene.',
  vi: 'LiteRT-LM khong the khoi dong Gemma 4 E2B tren iPhone nay. Viec thu lai tu dong da tam dung; hay thu cong sau khi doi thiet bi hoac dieu kien runtime.',
  th: 'LiteRT-LM ไม่สามารถเริ่ม Gemma 4 E2B บน iPhone เครื่องนี้ได้ จึงหยุดการลองใหม่อัตโนมัติไว้ก่อน โปรดลองใหม่ด้วยตนเองหลังเปลี่ยนอุปกรณ์หรือสภาพแวดล้อมการทำงาน',
  nl: 'LiteRT-LM kon Gemma 4 E2B niet starten op deze iPhone-runtime. Automatische nieuwe pogingen zijn gepauzeerd; probeer handmatig opnieuw na het wijzigen van apparaat of runtime-omstandigheden.',
  pl: 'LiteRT-LM nie mogl uruchomic Gemma 4 E2B na tym iPhonie. Automatyczne ponowne proby zostaly wstrzymane; sprobuj recznie po zmianie urzadzenia lub warunkow uruchomienia.',
  uk: 'LiteRT-LM не зміг запустити Gemma 4 E2B на цьому iPhone. Автоматичні повторні спроби призупинено; спробуй ще раз вручну після зміни пристрою або умов виконання.',
};

function localizeModelLoadFailure(message: string, locale: string): string {
  const resolvedLocale = resolveLocaleCode(locale);
  const normalizedMessage = message.toLowerCase();

  if (
    normalizedMessage.includes('below the current gemma 4 e2b ios baseline')
    || normalizedMessage.includes('内存低于 6gb')
  ) {
    return MODEL_LOW_MEMORY_MESSAGE[resolvedLocale] ?? MODEL_LOW_MEMORY_MESSAGE.en;
  }

  if (normalizedMessage.includes('litert-lm failed to initialize gemma 4 on this ios runtime')) {
    return MODEL_RUNTIME_INIT_MESSAGE[resolvedLocale] ?? MODEL_RUNTIME_INIT_MESSAGE.en;
  }

  return message || translateMessage(resolvedLocale, 'status.infer_failed');
}

function createId(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function isNativeAndroidApp(): boolean {
  return Capacitor.isNativePlatform() && Capacitor.getPlatform() === 'android';
}

function blurActiveTextInput(): void {
  if (typeof document === 'undefined') {
    return;
  }

  const activeElement = document.activeElement;
  if (
    activeElement instanceof HTMLInputElement
    || activeElement instanceof HTMLTextAreaElement
    || activeElement instanceof HTMLSelectElement
  ) {
    activeElement.blur();
  }
}

function buildAiMessage(
  response: TriageResponse,
  text: string,
  options?: { isStreaming?: boolean },
): BeaconMessage {
  return {
    id: createId('ai'),
    sender: 'ai',
    text: formatModelTextForDisplay(text),
    isStreaming: options?.isStreaming ?? false,
    isAuthoritative: response.isKnowledgeBacked,
    guidanceMode: response.guidanceMode,
    evidence: response.evidence,
    disclaimer: response.disclaimer,
  };
}

const SWIPE_BACK_EDGE_PX = 36;
const SWIPE_BACK_TRIGGER_PX = 92;
const SWIPE_BACK_DIRECTION_LOCK_PX = 10;
const SWIPE_BACK_MAX_VERTICAL_DRIFT_PX = 72;
const SWIPE_BACK_MAX_VISUAL_OFFSET_PX = 140;
const SHEET_DISMISS_TRIGGER_PX = 116;
const SHEET_DISMISS_DIRECTION_LOCK_PX = 10;
const SHEET_DISMISS_MAX_HORIZONTAL_DRIFT_PX = 72;
const SHEET_DISMISS_MAX_VISUAL_OFFSET_PX = 220;
const STREAM_UI_FLUSH_INTERVAL_MS = 80;

type SwipeBackPhase = 'idle' | 'pending' | 'dragging';

type SwipeBackState = {
  phase: SwipeBackPhase;
  startX: number;
  startY: number;
  lastOffset: number;
};

function createSwipeBackState(): SwipeBackState {
  return {
    phase: 'idle',
    startX: 0,
    startY: 0,
    lastOffset: 0,
  };
}

function formatResponseText(response: TriageResponse, streamedText?: string): string {
  return buildDisplayResponseText(response, streamedText);
}

function isPreparingModel(model: ModelDescriptor): boolean {
  return !model.isDownloaded
    && (model.downloadStatus === 'in_progress' || model.downloadStatus === 'partially_downloaded');
}

function choosePreferredReadyModel(models: ModelDescriptor[]): ModelDescriptor | null {
  return models.find((model) => model.isDownloaded && model.id === 'gemma-4-e2b')
    ?? models.find((model) => model.isDownloaded)
    ?? null;
}

function hasDownloadedModel(models: ModelDescriptor[]): boolean {
  return models.some((model) => model.isDownloaded);
}

function hasLoadedModel(models: ModelDescriptor[]): boolean {
  return models.some((model) => model.isLoaded);
}

function patchModelDownloadState(
  models: ModelDescriptor[],
  modelId: string,
  patch: { downloadStatus: ModelDownloadStatus; isDownloaded?: boolean },
): ModelDescriptor[] {
  return models.map((model) => (
    model.id === modelId
      ? {
          ...model,
          downloadStatus: patch.downloadStatus,
          isDownloaded: patch.isDownloaded ?? model.isDownloaded,
        }
      : model
  ));
}

function isBundledModelPlaceholder(model: ModelDescriptor): boolean {
  return model.id === DEFAULT_BUNDLED_MODEL_ID
    && model.isBundled === true
    && !model.isDownloaded;
}

function shouldKeepWaitingForBundledModel(models: ModelDescriptor[]): boolean {
  return models.length === 0
    || models.some(isPreparingModel)
    || models.every(isBundledModelPlaceholder);
}

function needsBundledModelRecovery(models: ModelDescriptor[]): boolean {
  return models.length === 0
    || models.every(isBundledModelPlaceholder);
}

const DEFAULT_BUNDLED_MODEL_ID = 'gemma-4-e2b';

async function recoverBundledModelState(
  bridge: BeaconBridge,
  options?: { retries?: number; retryDelayMs?: number },
): Promise<ModelDescriptor[]> {
  const retries = options?.retries ?? 2;
  const retryDelayMs = options?.retryDelayMs ?? 300;
  let latestModels: ModelDescriptor[] = [];

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const loadedModels = await bridge.loadModel(DEFAULT_BUNDLED_MODEL_ID);
      if (loadedModels.length > 0) {
        latestModels = loadedModels;
      }
    } catch {
      // If the direct load races with native startup, fall through to another list refresh.
    }

    if (hasDownloadedModel(latestModels)) {
      return latestModels;
    }

    try {
      const listedModels = await bridge.listModels();
      if (listedModels.length > 0 || latestModels.length === 0) {
        latestModels = listedModels;
      }
    } catch {
      // Keep the latest successful snapshot and retry below.
    }

    if (hasDownloadedModel(latestModels) || attempt === retries) {
      return latestModels;
    }

    await sleep(retryDelayMs * (attempt + 1));
  }

  return latestModels;
}

export default function App() {
  const { t, locale } = useI18n();
  const bridge = useMemo(() => getBeaconBridge(), []);

  const QUICK_ACTIONS = useMemo(() => [
    {
      label: t('panic.lost.label'),
      icon: '🧭',
      categoryHint: CANONICAL_SCENARIO_HINTS.LOST_DISCONNECTED,
      userText: t('panic.lost.text'),
    },
    {
      label: t('panic.quake.label'),
      icon: '🏚️',
      categoryHint: CANONICAL_SCENARIO_HINTS.EARTHQUAKE_RUINS,
      userText: t('panic.quake.text'),
    },
    {
      label: t('panic.fire.label'),
      icon: '🔥',
      categoryHint: CANONICAL_SCENARIO_HINTS.TRAPPED_IN_FIRE,
      userText: t('panic.fire.text'),
    },
    {
      label: t('panic.trauma.label'),
      icon: '🩸',
      categoryHint: CANONICAL_SCENARIO_HINTS.SEVERE_TRAUMA,
      userText: t('panic.trauma.text'),
    },
  ], [t]);

  function formatBattery(status: BatteryStatus | null): string {
    if (!status) {
      return t('battery.unknown');
    }
    return t('battery.level', { level: (status.level * 100).toFixed(0) });
  }

  const [messages, setMessages] = useState<BeaconMessage[]>([]);
  const { hash, navigate } = useHashRouter();
  const [chatInput, setChatInput] = useState('');
  const [showModelManager, setShowModelManager] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [sosActive, setSosActive] = useState(false);
  const [nodesCount, setNodesCount] = useState(0);
  const [batteryStatus, setBatteryStatus] = useState<BatteryStatus | null>(null);
  const [powerMode, setPowerMode] = useState<PowerMode>('normal');
  const [models, setModels] = useState<ModelDescriptor[]>([]);
  const [downloadProgress, setDownloadProgress] = useState<Record<string, number>>({});
  const [modelLoadFailure, setModelLoadFailure] = useState<string | null>(null);
  const [statusLine, setStatusLine] = useState(t('status.offline_ready'));
  const [triageSession, setTriageSession] = useState(createTriageSessionState);
  const [isRecoveringModel, setIsRecoveringModel] = useState(false);
  const [swipeBackOffset, setSwipeBackOffset] = useState(0);
  const [isSwipeBackTracking, setIsSwipeBackTracking] = useState(false);
  const [modelSheetOffset, setModelSheetOffset] = useState(0);
  const [isModelSheetDragging, setIsModelSheetDragging] = useState(false);
  const chatAreaRef = useRef<HTMLDivElement | null>(null);
  const modelsRef = useRef<ModelDescriptor[]>([]);
  const bootPromiseRef = useRef<Promise<void> | null>(null);
  const swipeBackRef = useRef<SwipeBackState>(createSwipeBackState());
  const modelSheetDismissRef = useRef<SwipeBackState>(createSwipeBackState());
  const modelManagerTouchAtRef = useRef(0);
  const modelManagerCloseTouchAtRef = useRef(0);
  const previousHashRef = useRef(hash);
  const activeInferenceRunRef = useRef(0);
  const syncRetryCountRef = useRef(0);
  const downloadStartTimeRef = useRef<Record<string, number>>({});
  const [isBootstrapping, setIsBootstrapping] = useState(true);
  const [isCancelling, setIsCancelling] = useState(false);
  const [isOnline, setIsOnline] = useState(true);
  const [isSwitchingPowerMode, setIsSwitchingPowerMode] = useState(false);
  const modelRequiredMessage = t('status.model_required');
  const modelPreparingMessage = t('status.model_preparing');
  const modelNotLoadedMessage = t('model.not_loaded');

  function beginInferenceRun(): number {
    activeInferenceRunRef.current += 1;
    return activeInferenceRunRef.current;
  }

  function invalidateInferenceRun(): number {
    activeInferenceRunRef.current += 1;
    return activeInferenceRunRef.current;
  }

  function isInferenceRunActive(runId: number): boolean {
    return activeInferenceRunRef.current === runId;
  }

  function resetConversationUiState(): void {
    setMessages([]);
    setChatInput('');
    setShowModelManager(false);
    setTriageSession(resetTriageSessionState());
    setIsStreaming(false);
    setSwipeBackOffset(0);
    setIsSwipeBackTracking(false);
    setModelSheetOffset(0);
    setIsModelSheetDragging(false);
    swipeBackRef.current = createSwipeBackState();
    modelSheetDismissRef.current = createSwipeBackState();
    setStatusLine(modelLoadFailure ?? t('status.offline_ready'));
  }

  useEffect(() => {
    const previousHash = previousHashRef.current;
    previousHashRef.current = hash;
    const isHomeRoute = hash === '#/' || hash === '';
    const cameFromChatRoute = previousHash === '#/chat';
    if (cameFromChatRoute && isHomeRoute && (messages.length > 0 || isStreaming)) {
      const hadActiveInference = isStreaming;
      invalidateInferenceRun();
      resetConversationUiState();
      if (hadActiveInference) {
        setIsCancelling(true);
        const cancel = bridge.cancelActiveInference().catch(() => undefined);
        const timeout = new Promise<void>((r) => setTimeout(r, 3000));
        void Promise.race([cancel, timeout]).finally(() => setIsCancelling(false));
      }
    }
  }, [bridge, hash, isStreaming, messages.length, modelLoadFailure, t]);

  // Update statusline localization when loaded initially
  useEffect(() => {
    setStatusLine(modelLoadFailure ?? t('status.offline_ready'));
  }, [modelLoadFailure, t]);

  useEffect(() => {
    let handle: { remove: () => Promise<void> } | undefined;
    Network.getStatus().then((s) => setIsOnline(s.connected)).catch(() => {});
    Network.addListener('networkStatusChange', (s) => {
      setIsOnline(s.connected);
    }).then((h) => { handle = h; });
    return () => { void handle?.remove(); };
  }, []);

  useEffect(() => {
    let isCancelled = false;

    const boot = async () => {
      try {
        await bridge.initialize();
        const initialBattery = await bridge.getBatteryStatus();
        const listedModels = await bridge.listModels().catch(() => [] as ModelDescriptor[]);
        const initialModels = needsBundledModelRecovery(listedModels)
          ? await recoverBundledModelState(bridge).catch(() => listedModels)
          : listedModels;
        const resolvedModels = initialModels.length > 0
          ? initialModels
          : (isNativeAndroidApp() ? [] : createFallbackDownloadCatalog());

        if (isCancelled) {
          return;
        }

        modelsRef.current = resolvedModels;
        setBatteryStatus(initialBattery);
        setPowerMode(initialBattery.forcedPowerMode);
        setModels(resolvedModels);
        if (shouldKeepWaitingForBundledModel(resolvedModels)) {
          setStatusLine(modelPreparingMessage);
        } else if (!hasDownloadedModel(resolvedModels)) {
          setShowModelManager(true);
          setStatusLine(modelNotLoadedMessage);
        }

        const initialWarning = resolveBatteryWarning(initialBattery, t);
        if (initialWarning) {
          setMessages((prev) => [
            ...prev,
            { id: createId('system'), sender: 'system', text: initialWarning },
          ]);
        }
      } catch (error) {
        if (isCancelled) {
          return;
        }

        const message = extractErrorMessage(error) || t('status.infer_failed');
        const localizedFailure = localizeModelLoadFailure(message, locale);
        setModelLoadFailure(localizedFailure);
        setShowModelManager(true);
        setMessages((prev) => [
          ...prev,
          { id: createId('system'), sender: 'system', text: t('error.generic', { message: localizedFailure }) },
        ]);
        setStatusLine(localizedFailure);
      } finally {
        if (!isCancelled) {
          setIsBootstrapping(false);
        }
      }
    };

    const bootPromise = boot();
    bootPromiseRef.current = bootPromise;

    return () => {
      isCancelled = true;
    };
  }, [bridge, locale, modelNotLoadedMessage, modelPreparingMessage, t]);

  useEffect(() => {
    modelsRef.current = models;
  }, [models]);

  useEffect(() => {
    if (isBootstrapping || modelLoadFailure != null) {
      return undefined;
    }

    let isCancelled = false;
    let timerId: number | undefined;

    const syncNativeModelState = async (): Promise<void> => {
      let stopAutoRetry = false;
      syncRetryCountRef.current += 1;

      try {
        const listedModels = await bridge.listModels();
        const nextModels = needsBundledModelRecovery(listedModels)
          ? await recoverBundledModelState(bridge)
          : listedModels;
        if (isCancelled) {
          return;
        }

        modelsRef.current = nextModels;
        setModels(nextModels);

        const waitingForBundledModel = shouldKeepWaitingForBundledModel(nextModels);
        const loaded = hasLoadedModel(nextModels);
        const readyModel = choosePreferredReadyModel(nextModels);

        if (waitingForBundledModel) {
          setStatusLine(modelPreparingMessage);
        } else if (readyModel && !loaded) {
          const loadedModels = await bridge.loadModel(readyModel.id);
          if (isCancelled) {
            return;
          }
          modelsRef.current = loadedModels;
          setModels(loadedModels);
          setModelLoadFailure(null);
          setStatusLine(t('status.model_switched'));
          closeModelManager();
        } else if (!readyModel && nextModels.length > 0) {
          setShowModelManager(true);
          setStatusLine(modelNotLoadedMessage);
        }
      } catch (error) {
        if (!isCancelled) {
          const message = extractErrorMessage(error);
          const localizedFailure = localizeModelLoadFailure(message, locale);
          if (shouldStopAutoModelRetry(message)) {
            stopAutoRetry = true;
            setModelLoadFailure(localizedFailure);
            setShowModelManager(true);
            setStatusLine(localizedFailure);
          } else {
            setStatusLine(localizedFailure);
          }
        }
      }

      if (isCancelled) {
        return;
      }

        const shouldContinue =
        !stopAutoRetry
        && modelLoadFailure == null
        && syncRetryCountRef.current < 20
        && (
          shouldKeepWaitingForBundledModel(modelsRef.current)
          || (hasDownloadedModel(modelsRef.current) && !hasLoadedModel(modelsRef.current))
        );

      if (shouldContinue) {
        timerId = window.setTimeout(() => {
          void syncNativeModelState();
        }, 1500);
      } else if (syncRetryCountRef.current >= 20 && !hasLoadedModel(modelsRef.current)) {
        setModelLoadFailure(t('status.model_sync_timeout'));
        setShowModelManager(true);
      }
    };

    const shouldStart =
      modelsRef.current.some(isPreparingModel)
      || (modelsRef.current.some((model) => model.isDownloaded) && !modelsRef.current.some((model) => model.isLoaded));

    if (shouldStart) {
      void syncNativeModelState();
    }

    return () => {
      isCancelled = true;
      if (timerId != null) {
        window.clearTimeout(timerId);
      }
    };
  }, [bridge, isBootstrapping, locale, modelLoadFailure, modelNotLoadedMessage, modelPreparingMessage, modelRequiredMessage, t]);

  useEffect(() => {
    if (!chatAreaRef.current) {
      return;
    }
    chatAreaRef.current.scrollTop = chatAreaRef.current.scrollHeight;
  }, [messages, isStreaming]);

  const activeModel = useMemo(
    () => models.find((model) => model.isLoaded) ?? null,
    [models],
  );
  const recommendedDownloadModel = useMemo(
    () => chooseRecommendedDownloadModel(models),
    [models],
  );
  const alternateDownloadModel = useMemo(
    () => chooseAlternateDownloadModel(models, recommendedDownloadModel?.id),
    [models, recommendedDownloadModel?.id],
  );
  const batteryWarning = batteryStatus ? resolveBatteryWarning(batteryStatus, t) : undefined;
  const hasConversationMessages = messages.some((message) => (
    message.sender === 'user' || message.sender === 'ai'
  ));
  const isChatRoute = hash === '#/chat';
  const isChatView = isChatRoute || hasConversationMessages;
  const showModelDownloadGuide =
    showModelManager
    && !isBootstrapping
    && modelLoadFailure == null
    && models.length > 0
    && !shouldKeepWaitingForBundledModel(models)
    && !hasDownloadedModel(models);

  async function waitForBootstrap(): Promise<void> {
    if (!bootPromiseRef.current) {
      for (let attempt = 0; attempt < 50 && !bootPromiseRef.current; attempt += 1) {
        await sleep(10);
      }
    }

    if (bootPromiseRef.current) {
      await bootPromiseRef.current;
    }
  }

  async function reconcileModelState(nextModels: ModelDescriptor[], nextStatusLine?: string): Promise<ModelDescriptor[]> {
    modelsRef.current = nextModels;
    setModels(nextModels);

    const readyModel = choosePreferredReadyModel(nextModels);
    const hasLoadedReadyModel = hasLoadedModel(nextModels);
    if (readyModel && !hasLoadedReadyModel) {
      const loadedModels = await bridge.loadModel(readyModel.id);
      modelsRef.current = loadedModels;
      setModels(loadedModels);
      setModelLoadFailure(null);
      setStatusLine(nextStatusLine ?? t('status.model_switched'));
      return loadedModels;
    }

    if (nextStatusLine) {
      setStatusLine(nextStatusLine);
    }
    return nextModels;
  }

  async function recoverBundledModelIntoState(): Promise<ModelDescriptor[]> {
    setIsRecoveringModel(true);
    setStatusLine(modelPreparingMessage);
    try {
      const recoveredModels = await recoverBundledModelState(bridge, { retries: 3, retryDelayMs: 350 });
      if (recoveredModels.length > 0) {
        return await reconcileModelState(recoveredModels, t('status.model_switched'));
      }
      const fallbackModels = isNativeAndroidApp() ? [] : createFallbackDownloadCatalog();
      modelsRef.current = fallbackModels;
      setModels(fallbackModels);
      setStatusLine(modelNotLoadedMessage);
      return fallbackModels;
    } finally {
      setIsRecoveringModel(false);
    }
  }

  async function ensureLocalModelReady(): Promise<boolean> {
    if (isBootstrapping) {
      await waitForBootstrap();
    }

    if (modelsRef.current.length === 0 || shouldKeepWaitingForBundledModel(modelsRef.current)) {
      await recoverBundledModelIntoState();
    }

    if (modelsRef.current.length > 0) {
      await reconcileModelState(modelsRef.current);
    }

    if (hasDownloadedModel(modelsRef.current) && hasLoadedModel(modelsRef.current)) {
      return true;
    }

    const systemMessage = modelsRef.current.length === 0
      ? modelRequiredMessage
      : (isRecoveringModel || shouldKeepWaitingForBundledModel(modelsRef.current))
        ? modelPreparingMessage
        : modelRequiredMessage;
    setShowModelManager(true);
    setStatusLine(systemMessage);
    setMessages((prev) => {
      if (prev.some((message) => message.sender === 'system' && message.text === systemMessage)) {
        return prev;
      }
      return [
        ...prev,
        { id: createId('system'), sender: 'system', text: systemMessage },
      ];
    });
    return false;
  }

  async function refreshBattery(nextMode?: PowerMode): Promise<void> {
    const status = nextMode
      ? await bridge.setPowerMode(nextMode)
      : await bridge.getBatteryStatus();
    setBatteryStatus(status);
    setPowerMode(status.forcedPowerMode);

    const localizedWarning = resolveBatteryWarning(status, t);
    if (localizedWarning) {
      setMessages((prev) => {
        if (prev.some((message) => message.text === localizedWarning)) {
          return prev;
        }
        return [
          ...prev,
          { id: createId('system'), sender: 'system', text: localizedWarning },
        ];
      });
    }
  }

  function handleClearChat() {
    const hadActiveInference = isStreaming;
    invalidateInferenceRun();
    resetConversationUiState();
    navigate('#/', true);
    if (hadActiveInference) {
      setIsCancelling(true);
      const cancel = bridge.cancelActiveInference().catch(() => undefined);
      const timeout = new Promise<void>((r) => setTimeout(r, 3000));
      void Promise.race([cancel, timeout]).finally(() => setIsCancelling(false));
    }
  }

  function resetModelSheetGesture(): void {
    modelSheetDismissRef.current = createSwipeBackState();
    setIsModelSheetDragging(false);
    setModelSheetOffset(0);
  }

  function closeModelManager(): void {
    resetModelSheetGesture();
    setShowModelManager(false);
  }

  function resetSwipeBackGesture(): void {
    swipeBackRef.current = createSwipeBackState();
    setIsSwipeBackTracking(false);
    setSwipeBackOffset(0);
  }

  function isLeadingEdgeTouch(clientX: number): boolean {
    if (typeof window === 'undefined') {
      return clientX <= SWIPE_BACK_EDGE_PX;
    }

    const isRtl = document.documentElement.dir === 'rtl';
    return isRtl
      ? clientX >= window.innerWidth - SWIPE_BACK_EDGE_PX
      : clientX <= SWIPE_BACK_EDGE_PX;
  }

  function getSwipeBackDistance(clientX: number): number {
    const { startX } = swipeBackRef.current;
    const isRtl = typeof document !== 'undefined' && document.documentElement.dir === 'rtl';
    return isRtl ? startX - clientX : clientX - startX;
  }

  function canHandleSwipeBack(): boolean {
    return isChatView && !showModelManager;
  }

  function isInteractiveTouchTarget(target: EventTarget | null): boolean {
    if (!(target instanceof Element)) {
      return false;
    }

    return Boolean(target.closest([
      'button',
      'input',
      'textarea',
      'select',
      'a',
      '[role="button"]',
      '.fixed-bottom-panel',
      '.model-panel',
      '.sheet-backdrop',
    ].join(',')));
  }

  function handleSwipeBackTouchStart(event: ReactTouchEvent<HTMLDivElement>): void {
    if (!canHandleSwipeBack()) {
      resetSwipeBackGesture();
      return;
    }

    if (isInteractiveTouchTarget(event.target)) {
      resetSwipeBackGesture();
      return;
    }

    const touch = event.touches[0];
    if (!touch || !isLeadingEdgeTouch(touch.clientX)) {
      resetSwipeBackGesture();
      return;
    }

    swipeBackRef.current = {
      phase: 'pending',
      startX: touch.clientX,
      startY: touch.clientY,
      lastOffset: 0,
    };
  }

  function handleSwipeBackTouchMove(event: ReactTouchEvent<HTMLDivElement>): void {
    const swipeState = swipeBackRef.current;
    if (swipeState.phase === 'idle' || !canHandleSwipeBack()) {
      return;
    }

    const touch = event.touches[0];
    if (!touch) {
      return;
    }

    const horizontalDistance = getSwipeBackDistance(touch.clientX);
    const verticalDistance = touch.clientY - swipeState.startY;

    if (swipeState.phase === 'pending') {
      if (Math.abs(verticalDistance) > SWIPE_BACK_DIRECTION_LOCK_PX && Math.abs(verticalDistance) > Math.abs(horizontalDistance)) {
        resetSwipeBackGesture();
        return;
      }

      if (horizontalDistance <= SWIPE_BACK_DIRECTION_LOCK_PX) {
        return;
      }

      swipeState.phase = 'dragging';
      setIsSwipeBackTracking(true);
    }

    if (horizontalDistance <= 0) {
      setSwipeBackOffset(0);
      swipeState.lastOffset = 0;
      return;
    }

    if (Math.abs(verticalDistance) > SWIPE_BACK_MAX_VERTICAL_DRIFT_PX) {
      resetSwipeBackGesture();
      return;
    }

    const offset = Math.min(horizontalDistance, SWIPE_BACK_MAX_VISUAL_OFFSET_PX);
    swipeState.lastOffset = offset;
    setSwipeBackOffset(offset);
    if (event.cancelable) {
      event.preventDefault();
    }
  }

  function handleSwipeBackTouchEnd(): void {
    const swipeDistance = swipeBackRef.current.lastOffset;
    const shouldGoBack = swipeBackRef.current.phase === 'dragging' && swipeDistance >= SWIPE_BACK_TRIGGER_PX;
    resetSwipeBackGesture();
    if (shouldGoBack) {
      handleClearChat();
    }
  }

  function handleModelSheetTouchStart(event: ReactTouchEvent<HTMLElement>): void {
    if (!showModelManager) {
      resetModelSheetGesture();
      return;
    }

    const touch = event.touches[0];
    if (!touch) {
      resetModelSheetGesture();
      return;
    }

    modelSheetDismissRef.current = {
      phase: 'pending',
      startX: touch.clientX,
      startY: touch.clientY,
      lastOffset: 0,
    };
  }

  function handleModelSheetTouchMove(event: ReactTouchEvent<HTMLElement>): void {
    const dismissState = modelSheetDismissRef.current;
    if (dismissState.phase === 'idle' || !showModelManager) {
      return;
    }

    const touch = event.touches[0];
    if (!touch) {
      return;
    }

    const horizontalDistance = touch.clientX - dismissState.startX;
    const verticalDistance = touch.clientY - dismissState.startY;

    if (dismissState.phase === 'pending') {
      if (
        Math.abs(horizontalDistance) > SHEET_DISMISS_DIRECTION_LOCK_PX
        && Math.abs(horizontalDistance) > Math.abs(verticalDistance)
      ) {
        resetModelSheetGesture();
        return;
      }

      if (verticalDistance <= SHEET_DISMISS_DIRECTION_LOCK_PX) {
        return;
      }

      dismissState.phase = 'dragging';
      setIsModelSheetDragging(true);
    }

    if (verticalDistance <= 0) {
      setModelSheetOffset(0);
      dismissState.lastOffset = 0;
      return;
    }

    if (Math.abs(horizontalDistance) > SHEET_DISMISS_MAX_HORIZONTAL_DRIFT_PX) {
      resetModelSheetGesture();
      return;
    }

    const offset = Math.min(verticalDistance, SHEET_DISMISS_MAX_VISUAL_OFFSET_PX);
    dismissState.lastOffset = offset;
    setModelSheetOffset(offset);
    if (event.cancelable) {
      event.preventDefault();
    }
  }

  function handleModelSheetTouchEnd(): void {
    const dismissDistance = modelSheetDismissRef.current.lastOffset;
    const shouldClose =
      modelSheetDismissRef.current.phase === 'dragging' && dismissDistance >= SHEET_DISMISS_TRIGGER_PX;
    resetModelSheetGesture();
    if (shouldClose) {
      closeModelManager();
    }
  }

  async function runTriage(
    request: Parameters<typeof attachTriageSession>[0],
    options?: { displayCategoryLabel?: string },
  ): Promise<void> {
    if (isStreaming) return;

    const requestWithSession = attachTriageSession(request, triageSession);
    if (triageSession.resetContext) {
      setTriageSession((current) => consumeTriageSessionReset(current));
    }

    const inferenceRunId = beginInferenceRun();
    setIsStreaming(true);
    setStatusLine(t('status.inferring'));
    const streamingMessageId = `stream-${createId('ai')}`;

    const userMessage: BeaconMessage = {
      id: createId('user'),
      sender: 'user',
      text: (options?.displayCategoryLabel ?? requestWithSession.categoryHint)
        ? `${t('system.message_prefix')}: ${options?.displayCategoryLabel ?? requestWithSession.categoryHint}`
        : requestWithSession.userText,
    };
    setMessages((prev) => [...prev, userMessage]);

    let streamedText = '';
    let finalResponse: TriageResponse | undefined;
    let lastStreamUiFlushAt = 0;
    let lastRenderedStreamText = '';

    const flushStreamingMessage = (force = false): void => {
      if (!isInferenceRunActive(inferenceRunId)) {
        return;
      }

      const formattedText = formatModelTextForDisplay(streamedText);
      if (!hasMeaningfulModelText(formattedText)) {
        return;
      }

      const now = Date.now();
      if (!force && now - lastStreamUiFlushAt < STREAM_UI_FLUSH_INTERVAL_MS) {
        return;
      }

      if (!force && formattedText === lastRenderedStreamText) {
        return;
      }

      lastStreamUiFlushAt = now;
      lastRenderedStreamText = formattedText;

      const partialResponse: TriageResponse = finalResponse ?? {
        summary: formattedText,
        steps: [],
        disclaimer: '',
        isKnowledgeBacked: false,
        guidanceMode: 'grounded',
        evidence: {
          authoritative: [],
          supporting: [],
          matchedCategories: [],
          queryTerms: [],
        },
        usedProfileName: activeModel?.name ?? 'Gemma 4 E2B',
      };

      setMessages((prev) => {
        const next = [...prev];
        const partialMessage = buildAiMessage(partialResponse, formattedText, {
          isStreaming: true,
        });
        const streamingIndex = next.findIndex((message) => message.id === streamingMessageId);
        if (streamingIndex >= 0) {
          next[streamingIndex] = { ...next[streamingIndex], ...partialMessage, id: streamingMessageId };
        } else {
          next.push({ ...partialMessage, id: streamingMessageId });
        }
        return next;
      });
    };

    try {
      for await (const chunk of bridge.triageStream(requestWithSession)) {
        if (!isInferenceRunActive(inferenceRunId)) {
          break;
        }

        if (chunk.delta) {
          streamedText += chunk.delta;
          flushStreamingMessage();
        }

        if (chunk.final) {
          finalResponse = chunk.final;
          flushStreamingMessage(true);
        }
      }

      if (!isInferenceRunActive(inferenceRunId)) {
        return;
      }

      if (finalResponse) {
        const response = finalResponse;
        const finalText = formatResponseText(response, streamedText);

        setMessages((prev) => {
          const next = [...prev];
          const finalMessage = buildAiMessage(response, finalText);
          const streamingIndex = next.findIndex((message) => message.id === streamingMessageId);
          if (streamingIndex >= 0) {
            next[streamingIndex] = { ...finalMessage, id: createId('ai') };
          } else {
            next.push(finalMessage);
          }
          return next;
        });

        setStatusLine(
          response.isKnowledgeBacked ? t('status.evidence_hit') : t('status.model_responded'),
        );
      }
    } catch (error) {
      if (!isInferenceRunActive(inferenceRunId)) {
        return;
      }
      const message = extractErrorMessage(error) || t('status.infer_failed');
      setMessages((prev) => [
        ...prev,
        { id: createId('system'), sender: 'system', text: t('error.generic', { message: message }) },
      ]);
      setStatusLine(t('status.infer_failed'));
    } finally {
      if (isInferenceRunActive(inferenceRunId)) {
        setIsStreaming(false);
        await refreshBattery();
      }
    }
  }

  async function handleQuickAction(
    displayCategoryLabel: string,
    categoryHint: string,
    userText: string,
  ): Promise<void> {
    if (isStreaming) return;
    navigate('#/chat');
    if (!(await ensureLocalModelReady())) {
      navigate('#/', true);
      return;
    }
    await runTriage(
      {
        categoryHint,
        userText,
        powerMode,
        locale,
      },
      { displayCategoryLabel },
    );
  }

  async function handleSendChat(event?: FormEvent): Promise<void> {
    event?.preventDefault();
    if (!chatInput.trim() || isStreaming) {
      return;
    }
    if (hash !== '#/chat') navigate('#/chat');
    if (!(await ensureLocalModelReady())) {
      return;
    }

    const input = chatInput.trim();
    setChatInput('');
    await runTriage({
      userText: input,
      powerMode,
      locale,
    });
  }

  async function handleVisualAnalysis(): Promise<void> {
    if (isStreaming) return;

    let inferenceRunId: number | null = null;
    try {
      setStatusLine(t('camera.capture_aria'));
      const photo = await CapacitorCamera.getPhoto({
        source: CameraSource.Prompt,
        resultType: CameraResultType.Base64,
        quality: 72,
        width: 1536,
        height: 1536,
        allowEditing: false,
        saveToGallery: false,
        correctOrientation: true,
        promptLabelHeader: t('action.visual_help'),
        promptLabelPhoto: t('action.import_photo'),
        promptLabelPicture: t('camera.capture_aria'),
        promptLabelCancel: t('camera.cancel'),
      });
      const imageBase64 = photo.base64String?.trim();
      if (!imageBase64) {
        throw new Error(t('status.infer_failed'));
      }

      if (!(await ensureLocalModelReady())) {
        return;
      }

      inferenceRunId = beginInferenceRun();
      setIsStreaming(true);
      if (hash !== '#/chat') navigate('#/chat');
      setMessages((prev) => [
        ...prev,
        {
          id: createId('user'),
          sender: 'user',
          text: t('system.visual_request'),
        },
      ]);

      const request = attachTriageSession(
        {
          userText: '',
          categoryHint: CANONICAL_SCENARIO_HINTS.VISUAL_HELP,
          powerMode,
          imageBase64,
          locale,
        },
        triageSession,
      );
      if (triageSession.resetContext) {
        setTriageSession((current) => consumeTriageSessionReset(current));
      }

      const response = await bridge.analyzeVisual(request);
      if (!isInferenceRunActive(inferenceRunId)) {
        return;
      }

      const text = formatResponseText(response);
      setMessages((prev) => [...prev, buildAiMessage(response, text)]);
      setStatusLine(response.isKnowledgeBacked ? t('status.visual_evidence') : t('status.model_responded'));
    } catch (error) {
      if (isCancelledCameraCapture(error)) {
        setStatusLine(modelLoadFailure ?? t('status.offline_ready'));
        return;
      }
      if (isCameraPermissionDenied(error)) {
        setMessages((prev) => [
          ...prev,
          { id: createId('system'), sender: 'system', text: t('camera.permission_denied') },
        ]);
        return;
      }
      if (inferenceRunId !== null && !isInferenceRunActive(inferenceRunId)) {
        return;
      }
      const message = extractErrorMessage(error) || t('status.infer_failed');
      setMessages((prev) => [
        ...prev,
        { id: createId('system'), sender: 'system', text: t('error.generic', { message: message }) },
      ]);
    } finally {
      if (inferenceRunId !== null && isInferenceRunActive(inferenceRunId)) {
        setIsStreaming(false);
        await refreshBattery();
      }
    }
  }

  async function handleToggleSos(): Promise<void> {
    const latestAiMessage = [...messages].reverse().find((message) => message.sender === 'ai');
    const summary = latestAiMessage?.text.split('\n')[0] ?? t('system.message_prefix');
    const next = await bridge.toggleSos({ summary, locale });
    setSosActive(next.active);
    setNodesCount(next.connectedPeers);
    setStatusLine(next.active ? t('status.sos_on') : t('status.sos_off'));
  }

  async function handleSwitchPowerMode(mode: PowerMode): Promise<void> {
    setIsSwitchingPowerMode(true);
    try {
      await refreshBattery(mode);
      setStatusLine(mode === 'doomsday' ? t('status.doomsday_on') : t('status.standard_power'));
    } finally {
      setIsSwitchingPowerMode(false);
    }
  }

  async function handleDownloadModel(modelId: string): Promise<void> {
    const targetModel = modelsRef.current.find((model) => model.id === modelId);
    if (targetModel && isPreparingModel(targetModel)) {
      setStatusLine(modelPreparingMessage);
      return;
    }

    try {
      setModelLoadFailure(null);
      syncRetryCountRef.current = 0;

      if (!targetModel?.isDownloaded) {
        setStatusLine(t('status.downloading', { modelId }));
        downloadStartTimeRef.current[modelId] = Date.now();
        setDownloadProgress((prev) => ({ ...prev, [modelId]: prev[modelId] ?? 0 }));
        const startedModels = patchModelDownloadState(modelsRef.current, modelId, {
          downloadStatus: 'in_progress',
          isDownloaded: false,
        });
        modelsRef.current = startedModels;
        setModels(startedModels);
        for await (const chunk of bridge.downloadModel(modelId)) {
          const fraction = Math.max(0, Math.min(1, chunk.fraction));
          setDownloadProgress((prev) => ({ ...prev, [modelId]: fraction }));
          const nextModels = patchModelDownloadState(modelsRef.current, modelId, {
            downloadStatus: chunk.status,
            isDownloaded: chunk.status === 'succeeded' ? true : undefined,
          });
          modelsRef.current = nextModels;
          setModels(nextModels);
        }
        setStatusLine(t('status.download_done', { modelId }));
      }

      const nextModels = await bridge.loadModel(modelId);
      modelsRef.current = nextModels;
      setModels(nextModels);
      setDownloadProgress((prev) => ({ ...prev, [modelId]: 1 }));
      setStatusLine(t('status.model_switched'));
      closeModelManager();
    } catch (error) {
      const message = extractErrorMessage(error);
      const localizedFailure = localizeModelLoadFailure(message, locale);
      setDownloadProgress((prev) => {
        const next = { ...prev };
        delete next[modelId];
        return next;
      });
      setModelLoadFailure(localizedFailure);
      setStatusLine(localizedFailure);
      setShowModelManager(true);
    }
  }

  async function handleToggleModelManager(): Promise<void> {
    if (showModelManager) {
      closeModelManager();
      return;
    }

    blurActiveTextInput();
    setShowModelManager(true);

    if (isBootstrapping) {
      await waitForBootstrap();
    }

    if (modelsRef.current.length === 0) {
      void recoverBundledModelIntoState();
    } else if (shouldKeepWaitingForBundledModel(modelsRef.current)) {
      void recoverBundledModelIntoState();
    } else if (modelsRef.current.some((model) => model.isDownloaded) && !modelsRef.current.some((model) => model.isLoaded)) {
      void reconcileModelState(modelsRef.current);
    }
  }

  function handleModelManagerButtonTouchEnd(event: ReactTouchEvent<HTMLButtonElement>): void {
    modelManagerTouchAtRef.current = Date.now();
    if (event.cancelable) {
      event.preventDefault();
    }
    event.stopPropagation();
    void handleToggleModelManager();
  }

  function handleModelManagerButtonClick(): void {
    if (Date.now() - modelManagerTouchAtRef.current < 450) {
      return;
    }
    void handleToggleModelManager();
  }

  function handleModelManagerCloseTouchEnd(event: ReactTouchEvent<HTMLButtonElement>): void {
    modelManagerCloseTouchAtRef.current = Date.now();
    if (event.cancelable) {
      event.preventDefault();
    }
    event.stopPropagation();
    closeModelManager();
  }

  function handleModelManagerCloseClick(): void {
    if (Date.now() - modelManagerCloseTouchAtRef.current < 450) {
      return;
    }
    closeModelManager();
  }

  useEffect(() => {
    if (!isNativeAndroidApp()) {
      return undefined;
    }

    let isDisposed = false;
    let listenerHandle: { remove: () => Promise<void> } | undefined;

    void CapacitorApp.addListener('backButton', () => {
      if (showModelManager) {
        closeModelManager();
        return;
      }

      if (hash === '#/chat' || hasConversationMessages) {
        handleClearChat();
        return;
      }

      void CapacitorApp.exitApp();
    }).then((handle) => {
      if (isDisposed) {
        void handle.remove();
        return;
      }

      listenerHandle = handle;
    });

    return () => {
      isDisposed = true;
      if (listenerHandle) {
        void listenerHandle.remove();
      }
    };
  }, [hash, hasConversationMessages, isStreaming, showModelManager]);

  return (
    <div
      className={`container ${isSwipeBackTracking ? 'container-swipe-active' : ''}`}
      style={{ '--swipe-back-offset': `${swipeBackOffset}px` } as CSSProperties}
      onTouchStart={handleSwipeBackTouchStart}
      onTouchMove={handleSwipeBackTouchMove}
      onTouchEnd={handleSwipeBackTouchEnd}
      onTouchCancel={resetSwipeBackGesture}
    >
      <NavBar
        showBack={isChatView}
        onBack={isChatView ? handleClearChat : undefined}
        sosActive={sosActive}
        nodesCount={nodesCount}
        statusLine={isCancelling ? t('status.cancelling') : statusLine}
        isOnline={isOnline}
        onStatusClick={() => void handleToggleModelManager()}
      />

      {batteryWarning && (
        <div className="warning-banner">
          <Zap size={16} />
          <span>{batteryWarning}</span>
        </div>
      )}

      <div className="chat-area" ref={chatAreaRef}>

        {!isChatView ? (
          <div className="empty-state">
            <div className="beacon-aura" aria-hidden="true">
              <span className="beacon-aura-core" />
              <span className="beacon-aura-ring ring-one" />
              <span className="beacon-aura-ring ring-two" />
            </div>
            <div className="hero-copy">
              <p className="hero-kicker">{t('hero.kicker')}</p>
              <h1>{t('hero.title')}</h1>
              <p>{t('hero.subtitle')}</p>
            </div>
            <div className="panic-grid">
              {QUICK_ACTIONS.map((action) => (
                <button
                  key={action.label}
                  className="panic-btn"
                  disabled={isStreaming}
                  onClick={() => void handleQuickAction(action.label, action.categoryHint, action.userText)}
                >
                  <span className="panic-icon-shell" aria-hidden="true">
                    <span className="icon">{action.icon}</span>
                  </span>
                  <span className="panic-label">{action.label}</span>
                </button>
              ))}
            </div>
            <button className="viewfinder-btn" disabled={isStreaming} onClick={() => void handleVisualAnalysis()}>
              <span className="viewfinder-icon-shell" aria-hidden="true">
                <CameraIcon size={21} strokeWidth={2.25} />
              </span>
              <span className="viewfinder-label">{t('action.visual_help')}</span>
            </button>
          </div>
        ) : (
          <>
            {messages.map((message) => (
              <article key={message.id} className={`message ${message.sender}`}>
                {message.isAuthoritative && !message.isStreaming && (
                  <div className="authoritative-badge">
                    <ShieldCheck size={14} />
                    {t('badge.authoritative')}
                  </div>
                )}
                {message.sender === 'ai' ? (
                  <MarkdownMessage text={message.text} />
                ) : (
                  <div className="message-text">{message.text}</div>
                )}
                {message.evidence &&
                  !message.isStreaming &&
                  message.evidence.authoritative.length > 0 && (
                    <div className="evidence-panel">
                      <div className="evidence-row">
                        <span className="evidence-label">{t('evidence.source')}</span>
                        <div className="evidence-chips">
                          {message.evidence.authoritative.map((item) => (
                            <span key={item.id} className="evidence-chip authority">
                              {item.source}
                            </span>
                          ))}
                        </div>
                      </div>
                    </div>
                  )}
                {message.disclaimer && !message.isStreaming && (
                  <div className="message-disclaimer">{message.disclaimer}</div>
                )}
              </article>
            ))}
          </>
        )}
        {isStreaming && (
          <div className="streaming-indicator" role="status" aria-live="polite">
            <LoaderCircle size={16} className="spin" />
            {t('chat.streaming')}
          </div>
        )}
      </div>

      <div className="fixed-bottom-panel">
        <form className="chat-input-wrapper" onSubmit={(event) => void handleSendChat(event)}>
          <input
            type="text"
            className="chat-input"
            placeholder={t('chat.input_placeholder')}
            aria-label={t('chat.input_placeholder')}
            value={chatInput}
            onChange={(event) => setChatInput(event.target.value)}
          />
          <button className="send-btn" type="submit" disabled={isStreaming}>
            {t('chat.send')}
          </button>
        </form>

        <div className="global-sos-section">
          <button
            className={`sos-btn ${sosActive ? 'active' : ''}`}
            onClick={() => void handleToggleSos()}
            aria-label={sosActive ? t('sos.stop') : t('sos.start')}
          >
            {sosActive ? t('sos.stop') : t('sos.start')}
          </button>
          <button
            className="model-mgr-btn"
            type="button"
            onClick={handleModelManagerButtonClick}
            onTouchEnd={handleModelManagerButtonTouchEnd}
            aria-label={t('model.manage')}
            title={t('model.manage')}
          >
            <Settings size={18} />
          </button>
        </div>
      </div>

      {showModelManager && (
        <div
          className="sheet-backdrop"
          onClick={closeModelManager}
          aria-hidden="true"
        />
      )}

      {showModelManager && (
        <section
          className={`model-panel ${isModelSheetDragging ? 'model-panel-dragging' : ''}`}
          style={{ '--sheet-dismiss-offset': `${modelSheetOffset}px` } as CSSProperties}
        >
          <div
            className="model-panel-header"
            onTouchStart={handleModelSheetTouchStart}
            onTouchMove={handleModelSheetTouchMove}
            onTouchEnd={handleModelSheetTouchEnd}
            onTouchCancel={resetModelSheetGesture}
          >
            <div className="model-panel-heading">
              <h2>{t('model.manage')}</h2>
              <LanguageSwitcher />
            </div>
            <button
              type="button"
              onClick={handleModelManagerCloseClick}
              onTouchEnd={handleModelManagerCloseTouchEnd}
              aria-label={t('model.close')}
            >
              {t('model.close')}
            </button>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', paddingBottom: '1rem', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
            <div>
              <div style={{ fontWeight: 600 }}>{formatBattery(batteryStatus)}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
                {powerMode === 'doomsday' ? t('power.doomsday.active') : t('power.normal.active')}
              </div>
            </div>
            <button
              className={`power-toggle ${powerMode === 'doomsday' ? 'active' : ''}`}
              onClick={() => void handleSwitchPowerMode(powerMode === 'normal' ? 'doomsday' : 'normal')}
              disabled={isSwitchingPowerMode}
            >
              {isSwitchingPowerMode
                ? <LoaderCircle size={14} className="spin" />
                : (powerMode === 'doomsday' ? t('power.normal.toggle') : t('power.doomsday.toggle'))}
            </button>
          </div>

          <div className="model-list">
            {modelLoadFailure && (
              <p className="model-error-note">{modelLoadFailure}</p>
            )}
            {showModelDownloadGuide && (
              <section className="model-onboarding-card" aria-label={t('status.model_required')}>
                <div className="model-onboarding-copy">
                  <span className="model-onboarding-kicker">Gemma 4</span>
                  <h3>{t('model.manage')}</h3>
                  <p>{t('status.model_required')}</p>
                </div>

                <div className="model-onboarding-actions">
                  {[recommendedDownloadModel, alternateDownloadModel].filter((model): model is ModelDescriptor => model != null).map((model, index) => {
                    const progress = downloadProgress[model.id];
                    const isBusy = isPreparingModel(model) || (progress != null && progress < 1);
                    const actionLabel = model.isDownloaded ? t('model.switch_btn') : t('model.download_btn');
                    const progressPercent = Math.round((progress ?? 0) * 100);

                    return (
                      <button
                        key={model.id}
                        type="button"
                        className={`model-onboarding-action ${index === 0 ? 'primary' : 'secondary'} ${isBusy ? 'downloading' : ''}`}
                        onClick={() => void handleDownloadModel(model.id)}
                        disabled={isBusy}
                        aria-busy={isBusy}
                        aria-label={`${actionLabel} ${model.name}`}
                      >
                        <div className="model-onboarding-action-row">
                          <span className="model-onboarding-action-title">{model.name}</span>
                          {isBusy ? <LoaderCircle size={15} className="spin" /> : <Download size={15} />}
                        </div>
                        <span className="model-onboarding-action-meta">
                          {formatModelSizeLabel(model, t)}
                        </span>
                        {isBusy && (
                          <span className="model-onboarding-action-progress">
                            <span className="model-progress-track" aria-hidden="true">
                              <span
                                className="model-progress-fill"
                                style={{ width: `${Math.max(4, progressPercent)}%` }}
                              />
                            </span>
                            <span>
                              {t('model.downloading', { progress: progressPercent.toFixed(0) })}
                              {formatDownloadEta(downloadStartTimeRef.current[model.id], progress ?? 0)}
                            </span>
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              </section>
            )}
            {models.length === 0 ? (
              <p className="model-empty">
                {isBootstrapping || isRecoveringModel || modelLoadFailure == null
                  ? t('model.preparing')
                  : t('model.not_loaded')}
              </p>
            ) : showModelDownloadGuide ? null : (
              models.map((model) => (
                <div key={model.id} className={`model-card ${model.isLoaded ? 'loaded' : ''}`}>
                  <div className="model-card-copy">
                    <div className="model-card-heading">
                      <strong>{model.name}</strong>
                      <span className={`model-tier-badge tier-${model.tier}`}>
                        {formatModelSizeLabel(model, t)}
                      </span>
                    </div>
                    <p>
                      {model.isLoaded
                        ? t('model.loaded_tag')
                        : model.isDownloaded
                          ? t('model.switch_btn')
                          : t('model.download_btn')}
                    </p>
                  </div>
                  <div className="model-actions">
                    {(() => {
                      const progress = downloadProgress[model.id];
                      const isBusy = isPreparingModel(model) || (progress != null && progress < 1);
                      const progressPercent = Math.round((progress ?? 0) * 100);

                      if (model.isLoaded) {
                        return <span className="loaded-tag">{t('model.loaded_tag')}</span>;
                      }

                      if (isBusy) {
                        return (
                          <div className="download-progress" role="status" aria-live="polite">
                            <span className="model-progress-track" aria-hidden="true">
                              <span
                                className="model-progress-fill"
                                style={{ width: `${Math.max(4, progressPercent)}%` }}
                              />
                            </span>
                            <span>
                              {t('model.downloading', { progress: progressPercent.toFixed(0) })}
                              {formatDownloadEta(downloadStartTimeRef.current[model.id], progress ?? 0)}
                            </span>
                          </div>
                        );
                      }

                      return (
                        <button onClick={() => void handleDownloadModel(model.id)}>
                          <Download size={14} />
                          {model.isDownloaded ? t('model.switch_btn') : t('model.download_btn')}
                        </button>
                      );
                    })()}
                  </div>
                </div>
              ))
            )}
          </div>
        </section>
      )}
    </div>
  );
}
