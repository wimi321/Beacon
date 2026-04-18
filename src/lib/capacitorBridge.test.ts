import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createCapacitorBeaconBridge } from './capacitorBridge';
import { NativeBeacon } from './nativeBeaconPlugin';
import type { TriageResponse } from './types';

const nativeState = vi.hoisted(() => {
  let streamListener:
    | ((event: {
        streamId: string;
        delta?: string;
        done?: boolean;
        error?: string;
        finalText?: string;
        usedProfileName?: string;
      }) => void)
    | undefined;

  return {
    get listener() {
      return streamListener;
    },
    setListener(listener: typeof streamListener) {
      streamListener = listener;
    },
    removeListener() {
      streamListener = undefined;
    },
  };
});

vi.mock('@capacitor/core', () => ({
  Capacitor: {
    isNativePlatform: () => true,
  },
}));

vi.mock('@capacitor/device', () => ({
  Device: {
    getBatteryInfo: vi.fn(),
  },
}));

vi.mock('@capacitor/geolocation', () => ({
  Geolocation: {
    getCurrentPosition: vi.fn(),
  },
}));

vi.mock('@capacitor/haptics', () => ({
  ImpactStyle: {
    Light: 'LIGHT',
    Medium: 'MEDIUM',
    Heavy: 'HEAVY',
  },
  Haptics: {
    impact: vi.fn(async () => undefined),
  },
}));

vi.mock('@capacitor/network', () => ({
  Network: {
    getStatus: vi.fn(async () => ({ connected: false })),
  },
}));

vi.mock('@capacitor/preferences', () => ({
  Preferences: {
    get: vi.fn(async () => ({ value: null })),
    set: vi.fn(async () => undefined),
  },
}));

vi.mock('./beaconEngine', () => ({
  buildGroundingContext: vi.fn(() => 'grounding-context'),
  estimateSosState: vi.fn(),
  retrieveEvidenceBundle: vi.fn(() => ({
    authoritative: [
      {
        id: 'auth-1',
        sourceId: 'ready-gov',
        title: 'Severe Bleeding',
        source: 'Ready.gov',
        summary: 'Apply direct pressure.',
        steps: ['Use clean cloth or gauze.'],
        contraindications: [],
        escalation: 'Call emergency services.',
        strategy: 'lexical',
        score: 0.99,
      },
    ],
    supporting: [],
    matchedCategories: ['bleeding'],
    queryTerms: ['bleeding'],
  })),
  warmKnowledgeEngine: vi.fn(async () => undefined),
}));

vi.mock('./nativeBeaconPlugin', () => ({
  NativeBeacon: {
    addListener: vi.fn(async (eventName: string, listener: typeof nativeState.listener) => {
      if (eventName === 'triageStreamEvent') {
        nativeState.setListener(listener);
      }
      return {
        remove: vi.fn(async () => {
          nativeState.removeListener();
        }),
      };
    }),
    analyzeVisual: vi.fn(),
    downloadModel: vi.fn(),
    getRuntimeDiagnostics: vi.fn(),
    listModels: vi.fn(async () => ({ models: [] })),
    loadModel: vi.fn(async () => ({ models: [] })),
    triage: vi.fn(),
    triageStream: vi.fn(async ({ streamId }: { streamId?: string }) => {
      queueMicrotask(() => {
        nativeState.listener?.({
          streamId: streamId ?? 'missing-stream',
          delta: 'Keep firm pressure on the wound. ',
        });
        nativeState.listener?.({
          streamId: streamId ?? 'missing-stream',
          delta: 'Call emergency services now.',
        });
        nativeState.listener?.({
          streamId: streamId ?? 'missing-stream',
          done: true,
          finalText: 'Keep firm pressure on the wound.\n1. Call emergency services now.',
          usedProfileName: 'gemma-4-e2b-balanced',
        });
      });
      return { streamId: streamId ?? 'missing-stream' };
    }),
  },
}));

describe('CapacitorBeaconBridge', () => {
  beforeEach(() => {
    nativeState.removeListener();
    vi.clearAllMocks();
  });

  it('yields real native stream deltas before the final response', async () => {
    const bridge = createCapacitorBeaconBridge();
    const chunks: Array<{ delta: string; done?: boolean; finalSummary?: string }> = [];

    for await (const chunk of bridge.triageStream({
      userText: 'There is heavy bleeding from the arm',
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'stream-test-session',
    })) {
      chunks.push({
        delta: chunk.delta,
        done: chunk.done,
        finalSummary: chunk.final?.summary,
      });
    }

    expect(chunks[0]).toMatchObject({
      delta: 'Keep firm pressure on the wound. ',
    });
    expect(chunks[1]).toMatchObject({
      delta: 'Call emergency services now.',
    });
    expect(chunks[2]).toMatchObject({
      delta: '',
      done: true,
      finalSummary: 'Keep firm pressure on the wound.',
    });
  });

  it('sends a simple visual request and keeps the image payload for native multimodal inference', async () => {
    vi.mocked(NativeBeacon.analyzeVisual).mockResolvedValue({
      text: 'Check the wound.\n1. Keep pressure on it.',
      modelId: 'gemma-4-e2b',
      usedProfileName: 'gemma-4-e2b-balanced',
    });

    const bridge = createCapacitorBeaconBridge();
    await bridge.analyzeVisual({
      userText: '',
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'visual-test-session',
      imageBase64: 'ZmFrZS1pbWFnZS1ieXRlcw==',
    });

    expect(NativeBeacon.analyzeVisual).toHaveBeenCalledWith(
      expect.objectContaining({
        userText: 'Look at this image and tell me what is dangerous and what to do next.',
        imageBase64: 'ZmFrZS1pbWFnZS1ieXRlcw==',
      }),
    );
  });

  it('localizes the bottom disclaimer instead of hardcoding Chinese', async () => {
    vi.mocked(NativeBeacon.triage).mockResolvedValue({
      text: 'Stay where you are.\n1. Make yourself visible.',
      modelId: 'gemma-4-e2b',
      usedProfileName: 'gemma-4-e2b-balanced',
    });

    const bridge = createCapacitorBeaconBridge();
    const response = await bridge.triage({
      userText: 'I am lost in the forest',
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'localized-disclaimer-session',
    });

    expect(response.disclaimer).toContain('local model');
    expect(response.disclaimer).not.toContain('此回答由本地模型');
  });

  it('preserves native final text for display formatting instead of trimming it flat', async () => {
    vi.mocked(NativeBeacon.triageStream).mockImplementationOnce(async ({ streamId }: { streamId?: string }) => {
      queueMicrotask(() => {
        nativeState.listener?.({
          streamId: streamId ?? 'missing-stream',
          delta: '\nStay where you are.',
        });
        nativeState.listener?.({
          streamId: streamId ?? 'missing-stream',
          done: true,
          finalText: '\nStay where you are.\n\n- Make yourself visible\n',
          usedProfileName: 'gemma-4-e2b-balanced',
        });
      });
      return { streamId: streamId ?? 'missing-stream' };
    });

    const bridge = createCapacitorBeaconBridge();
    let finalResponse: TriageResponse | undefined;

    for await (const chunk of bridge.triageStream({
      userText: 'I am lost in the forest',
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'stream-raw-text-session',
    })) {
      if (chunk.final) {
        finalResponse = chunk.final;
      }
    }

    expect((finalResponse as TriageResponse & { rawText?: string })?.rawText).toBe(
      '\nStay where you are.\n\n- Make yourself visible\n',
    );
  });
});
