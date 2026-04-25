import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import App from './App';
import { I18nProvider } from './i18n';
import { createMockBeaconBridge } from './lib/mockBridge';
import type { TriageResponse } from './lib/types';

const cameraPluginState = vi.hoisted(() => ({
  getPhotoMock: vi.fn(async () => ({ base64String: 'ZmFrZS1pbWFnZS1ieXRlcw==' })),
  reset() {
    this.getPhotoMock.mockReset();
    this.getPhotoMock.mockResolvedValue({ base64String: 'ZmFrZS1pbWFnZS1ieXRlcw==' });
  },
}));

const appPluginState = vi.hoisted(() => {
  let backButtonListener:
    | ((event: { canGoBack: boolean }) => void)
    | undefined;
  let nativePlatform = false;
  let platform = 'web';
  let exitAppCalls = 0;

  return {
    clearBackButtonListener() {
      backButtonListener = undefined;
    },
    get exitAppCalls() {
      return exitAppCalls;
    },
    get hasBackButtonListener() {
      return typeof backButtonListener === 'function';
    },
    get platform() {
      return platform;
    },
    isNativePlatform() {
      return nativePlatform;
    },
    recordExitApp() {
      exitAppCalls += 1;
    },
    reset() {
      backButtonListener = undefined;
      nativePlatform = false;
      platform = 'web';
      exitAppCalls = 0;
    },
    setBackButtonListener(listener: typeof backButtonListener) {
      backButtonListener = listener;
    },
    setPlatform(nextPlatform: string, nextNativePlatform = true) {
      platform = nextPlatform;
      nativePlatform = nextNativePlatform;
    },
    triggerBackButton(event: { canGoBack: boolean } = { canGoBack: false }) {
      backButtonListener?.(event);
    },
  };
});

vi.mock('@capacitor/core', async () => {
  const actual = await vi.importActual<typeof import('@capacitor/core')>('@capacitor/core');

  return {
    ...actual,
    Capacitor: {
      ...actual.Capacitor,
      getPlatform: () => appPluginState.platform,
      isNativePlatform: () => appPluginState.isNativePlatform(),
    },
  };
});

vi.mock('@capacitor/camera', () => ({
  Camera: {
    getPhoto: cameraPluginState.getPhotoMock,
  },
  CameraResultType: {
    Base64: 'base64',
  },
  CameraSource: {
    Camera: 'camera',
    Prompt: 'prompt',
    Photos: 'photos',
  },
}));

vi.mock('@capacitor/app', () => ({
  App: {
    addListener: vi.fn(async (eventName: string, listener: (event: { canGoBack: boolean }) => void) => {
      if (eventName === 'backButton') {
        appPluginState.setBackButtonListener(listener);
      }

      return {
        remove: vi.fn(async () => {
          appPluginState.clearBackButtonListener();
        }),
      };
    }),
    exitApp: vi.fn(async () => {
      appPluginState.recordExitApp();
    }),
  },
}));

function renderApp(locale: string = 'zh-CN') {
  window.localStorage.setItem('beacon_locale', locale);
  window.beaconBridge = createMockBeaconBridge();
  return render(
    <I18nProvider>
      <App />
    </I18nProvider>,
  );
}

describe('App', () => {
  beforeEach(() => {
    appPluginState.reset();
    cameraPluginState.reset();
    window.beaconBridge = undefined;
    localStorage.removeItem('beacon_locale');
    window.location.hash = '#/';
  });

  it('renders panic actions and streams a grounded response', async () => {
    const { container } = renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));

    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 3000 })).toBeInTheDocument();

    await waitFor(() => {
      expect(container.querySelector('.authoritative-badge')).not.toBeNull();
    }, { timeout: 3000 });

    expect(screen.getByText(/远离浓烟源，尽量降低吸入量并寻找清洁空气/)).toBeInTheDocument();
    expect(screen.getByText(/进入封闭车辆或坚固建筑时立即关闭外循环和门窗/)).toBeInTheDocument();
    expect(container.querySelector('.conservative-badge')).toBeNull();
  });

  it('renders localized home copy for non-Chinese supported languages', async () => {
    renderApp('fr');

    expect(await screen.findByRole('heading', { name: /Survis d'abord, réfléchis ensuite/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Perdu \/ Sans signal/i })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: /先活下来，再想别的/i })).toBeNull();
  });

  it('keeps the home screen visible when boot only adds a localized battery warning', async () => {
    const mockBridge = createMockBeaconBridge();
    mockBridge.getBatteryStatus = async () => ({
      level: 0.08,
      isLowPowerMode: true,
      forcedPowerMode: 'doomsday',
      warningCode: 'battery.low_power_emergency',
      warning: '当前电量极低，已切换为极限抢险省电方案。',
    });

    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    expect(await screen.findByRole('heading', { name: /先活下来，再想别的/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /迷路断联/i })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /返回主页/i })).toBeNull();
  });

  it('falls back to the static download catalog when native model discovery transiently fails on boot', async () => {
    const mockBridge = createMockBeaconBridge();
    mockBridge.listModels = async () => {
      throw new Error('Transient native model listing failure');
    };
    mockBridge.loadModel = async () => {
      throw new Error('No bundled model ready yet');
    };

    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    expect(await screen.findByRole('heading', { name: /先活下来，再想别的/i })).toBeInTheDocument();
    expect(screen.queryByText(/生成建议失败，请重试/)).toBeNull();
    expect(screen.queryByText(/错误：Transient native model listing failure/)).toBeNull();
    expect(await screen.findByRole('button', { name: /下载并切换 Gemma 4 E2B/i })).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: /下载并切换 Gemma 4 E4B/i })).toBeInTheDocument();
  });

  it('opens model manager and shows loaded model', async () => {
    renderApp('zh-CN');

    fireEvent.click((await screen.findAllByRole('button', { name: /设置与模型/i }))[0]);

    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);
  });

  it('opens model manager from a touch-end activation on the settings button', async () => {
    renderApp('zh-CN');

    fireEvent.touchEnd((await screen.findAllByRole('button', { name: /设置与模型/i }))[0], {
      cancelable: true,
      changedTouches: [{ clientX: 960, clientY: 2240 }],
    });

    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);
  });

  it('auto-opens first-launch model guidance and lets users download E2B directly', async () => {
    let downloadedModelId: string | null = null;
    const mockBridge = createMockBeaconBridge();
    const baseModels = [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b' as const,
        name: 'Gemma 4 E2B',
        localPath: '',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: false,
        isDownloaded: false,
        downloadStatus: 'not_downloaded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'iphone_primary' as const,
      },
      {
        id: 'gemma-4-e4b',
        tier: 'e4b' as const,
        name: 'Gemma 4 E4B',
        localPath: '',
        sizeLabel: '4B / Enhanced Accuracy',
        isLoaded: false,
        isDownloaded: false,
        downloadStatus: 'not_downloaded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'iphone_primary' as const,
      },
    ];

    const snapshotModels = (activeModelId: string | null = downloadedModelId) => baseModels.map((model) => ({
      ...model,
      isDownloaded: downloadedModelId === model.id,
      isLoaded: activeModelId === model.id,
      downloadStatus: downloadedModelId === model.id ? 'succeeded' as const : 'not_downloaded' as const,
    }));

    mockBridge.listModels = async () => snapshotModels(null);
    mockBridge.loadModel = async (modelId: string) => snapshotModels(downloadedModelId === modelId ? modelId : null);
    mockBridge.downloadModel = async function* (modelId: string) {
      yield {
        modelId,
        receivedBytes: 64,
        totalBytes: 128,
        fraction: 0.5,
        isResumed: false,
        status: 'in_progress' as const,
      };
      downloadedModelId = modelId;
      yield {
        modelId,
        receivedBytes: 128,
        totalBytes: 128,
        fraction: 1,
        isResumed: false,
        status: 'succeeded' as const,
      };
    };

    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    expect((await screen.findAllByText(/请先在设置中下载离线急救包，再开始求救/)).length).toBeGreaterThan(0);
    expect(screen.getByRole('button', { name: /下载并切换 Gemma 4 E2B/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /下载并切换 Gemma 4 E4B/i })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /下载并切换 Gemma 4 E2B/i }));

    await waitFor(() => {
      expect(screen.getByText(/模型切换完成/)).toBeInTheDocument();
    });

    fireEvent.click(screen.getByRole('button', { name: /设置与模型/i }));
    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);
  });

  it('closes the model manager when swiping the sheet downward', async () => {
    const { container } = renderApp('zh-CN');

    fireEvent.click((await screen.findAllByRole('button', { name: /设置与模型/i }))[0]);
    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);

    const sheetHeader = container.querySelector('.model-panel-header');
    expect(sheetHeader).not.toBeNull();

    fireEvent.touchStart(sheetHeader as Element, {
      touches: [{ clientX: 180, clientY: 120 }],
    });
    fireEvent.touchMove(sheetHeader as Element, {
      touches: [{ clientX: 188, clientY: 266 }],
      cancelable: true,
    });
    fireEvent.touchEnd(sheetHeader as Element, {
      changedTouches: [{ clientX: 188, clientY: 266 }],
    });

    await waitFor(() => {
      expect(screen.queryAllByText(/当前已加载/)).toHaveLength(0);
    });
  });

  it('recovers from an empty native model list by auto-loading the bundled Gemma model', async () => {
    let listCalls = 0;
    let loadAttempts = 0;
    const mockBridge = createMockBeaconBridge();
    const recoveredModels = [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b' as const,
        name: 'Gemma 4 E2B',
        localPath: 'models/gemma-4-E2B-it.litertlm',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: true,
        isDownloaded: true,
        downloadStatus: 'succeeded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'iphone_primary' as const,
      },
    ];

    mockBridge.listModels = async () => {
      listCalls += 1;
      return listCalls === 1 ? [] : recoveredModels;
    };
    mockBridge.loadModel = async () => {
      loadAttempts += 1;
      return recoveredModels;
    };
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click((await screen.findAllByRole('button', { name: /设置与模型/i }))[0]);

    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);
    expect(screen.queryByText('未加载模型')).toBeNull();
    expect(loadAttempts).toBeGreaterThanOrEqual(1);
  });

  it('recovers the bundled model before handling a panic action', async () => {
    let listCalls = 0;
    let loadAttempts = 0;
    const mockBridge = createMockBeaconBridge();
    const recoveredModels = [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b' as const,
        name: 'Gemma 4 E2B',
        localPath: 'models/gemma-4-E2B-it.litertlm',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: true,
        isDownloaded: true,
        downloadStatus: 'succeeded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'iphone_primary' as const,
      },
    ];

    mockBridge.listModels = async () => {
      listCalls += 1;
      return listCalls === 1 ? [] : recoveredModels;
    };
    mockBridge.loadModel = async () => {
      loadAttempts += 1;
      return recoveredModels;
    };
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));

    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 3000 })).toBeInTheDocument();
    expect(screen.queryByText(/请先在设置中下载离线急救包/)).toBeNull();
    expect(loadAttempts).toBeGreaterThanOrEqual(1);
  });

  it('recovers the bundled model when native reports an unloaded placeholder entry', async () => {
    let listCalls = 0;
    let loadAttempts = 0;
    const mockBridge = createMockBeaconBridge();
    const unloadedPlaceholder = [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b' as const,
        name: 'Gemma 4 E2B',
        localPath: 'models/gemma-4-E2B-it.litertlm',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: false,
        isBundled: true,
        isDownloaded: false,
        downloadStatus: 'not_downloaded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'iphone_primary' as const,
      },
    ];
    const recoveredModels = [
      {
        ...unloadedPlaceholder[0],
        isLoaded: true,
        isDownloaded: true,
        downloadStatus: 'succeeded' as const,
      },
    ];

    mockBridge.listModels = async () => {
      listCalls += 1;
      return listCalls === 1 ? unloadedPlaceholder : recoveredModels;
    };
    mockBridge.loadModel = async () => {
      loadAttempts += 1;
      return recoveredModels;
    };
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click((await screen.findAllByRole('button', { name: /设置与模型/i }))[0]);

    expect((await screen.findAllByText(/当前已加载/)).length).toBeGreaterThan(0);
    expect(screen.queryByText(/请先在设置中下载离线急救包/)).toBeNull();
    expect(loadAttempts).toBeGreaterThanOrEqual(1);
  });

  it('keeps showing preparing instead of model-not-loaded while bundled iOS model is still bootstrapping', async () => {
    const mockBridge = createMockBeaconBridge();
    const bootstrappingPlaceholder = [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b' as const,
        name: 'Gemma 4 E2B',
        localPath: 'models/gemma-4-E2B-it.litertlm',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: false,
        isBundled: true,
        isDownloaded: false,
        downloadStatus: 'not_downloaded' as const,
        artifactFormat: 'litertlm' as const,
        runtimeStack: 'litert-lm-c-api' as const,
        preferredBackend: 'auto-real' as const,
        capabilityClass: 'supported' as const,
        supportedDeviceClass: 'ipad_compat' as const,
      },
    ];

    mockBridge.listModels = async () => bootstrappingPlaceholder;
    mockBridge.loadModel = async () => bootstrappingPlaceholder;
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click((await screen.findAllByRole('button', { name: /设置与模型/i }))[0]);

    expect(await screen.findByText(/正在准备离线急救系统，请保持应用开启/)).toBeInTheDocument();
    expect(screen.queryByText('未加载模型')).toBeNull();
    expect(screen.queryByText(/请先在设置中下载离线急救包/)).toBeNull();
  });

  it('clears chat back to home state', async () => {
    renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 3000 })).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText(/正在生成建议\.\.\./)).not.toBeInTheDocument();
    });

    fireEvent.click(screen.getByLabelText('返回主页'));

    await waitFor(() => {
      expect(screen.getByRole('heading', { name: /先活下来，再想别的/ })).toBeInTheDocument();
      expect(screen.queryByText(/尽量用湿布或多层布料遮住口鼻/)).not.toBeInTheDocument();
    });
  });

  it('returns home while streaming and ignores late chunks', async () => {
    let isReleased = false;
    const releaseStream = () => {
      isReleased = true;
    };
    const cancelActiveInference = vi.fn(async () => undefined);
    const mockBridge = createMockBeaconBridge();
    mockBridge.cancelActiveInference = cancelActiveInference;
    mockBridge.triageStream = async function* () {
      yield { delta: '先处理明显危险。' };

      while (!isReleased) {
        await new Promise((resolve) => window.setTimeout(resolve, 10));
      }

      yield { delta: '这段晚到的内容不该再出现。' };
      yield {
        delta: '',
        done: true,
        final: {
          summary: '最终整段回答不该再出现。',
          steps: ['继续观察周围环境。'],
          disclaimer: '',
          isKnowledgeBacked: false,
          guidanceMode: 'grounded',
          evidence: {
            authoritative: [],
            supporting: [],
            matchedCategories: [],
            queryTerms: [],
          },
          usedProfileName: 'gemma-4-e2b-balanced',
        },
      };
    };
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    expect(await screen.findByText('先处理明显危险。')).toBeInTheDocument();
    const chatInput = screen.getByPlaceholderText('输入你现在的情况......');
    expect(chatInput).not.toBeDisabled();
    fireEvent.change(chatInput, { target: { value: '我还在二楼窗口旁边' } });
    expect(chatInput).toHaveValue('我还在二楼窗口旁边');
    fireEvent.click(screen.getByLabelText('返回主页'));

    await waitFor(() => {
      expect(screen.getByRole('heading', { name: /先活下来，再想别的/ })).toBeInTheDocument();
    });
    expect(cancelActiveInference).toHaveBeenCalledTimes(1);

    releaseStream();
    await new Promise((resolve) => window.setTimeout(resolve, 80));

    expect(screen.queryByText('这段晚到的内容不该再出现。')).toBeNull();
    expect(screen.queryByText('最终整段回答不该再出现。')).toBeNull();
  });

  it('returns home on a leading-edge right swipe while in chat', async () => {
    const { container } = renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 8000 })).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText(/正在生成建议\.\.\./)).not.toBeInTheDocument();
    }, { timeout: 8000 });

    const appContainer = container.querySelector('.container');
    expect(appContainer).not.toBeNull();

    fireEvent.touchStart(appContainer as Element, {
      touches: [{ clientX: 12, clientY: 180 }],
    });
    fireEvent.touchMove(appContainer as Element, {
      touches: [{ clientX: 132, clientY: 188 }],
      cancelable: true,
    });
    fireEvent.touchEnd(appContainer as Element, {
      changedTouches: [{ clientX: 132, clientY: 188 }],
    });

    await waitFor(() => {
      expect(screen.getByRole('heading', { name: /先活下来，再想别的/ })).toBeInTheDocument();
      expect(screen.queryByText(/尽量用湿布或多层布料遮住口鼻/)).not.toBeInTheDocument();
    });
  });

  it('handles Android system back inside the app before exiting', async () => {
    appPluginState.setPlatform('android');
    renderApp('zh-CN');

    await waitFor(() => {
      expect(appPluginState.hasBackButtonListener).toBe(true);
    });

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 3000 })).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText(/正在生成建议\.\.\./)).not.toBeInTheDocument();
    });

    appPluginState.triggerBackButton();

    await waitFor(() => {
      expect(screen.getByRole('heading', { name: /先活下来，再想别的/ })).toBeInTheDocument();
      expect(screen.queryByText(/尽量用湿布或多层布料遮住口鼻/)).not.toBeInTheDocument();
    });

    expect(appPluginState.exitAppCalls).toBe(0);
  });

  it('lets Android system back exit only when already at the home screen', async () => {
    appPluginState.setPlatform('android');
    renderApp('zh-CN');

    await waitFor(() => {
      expect(appPluginState.hasBackButtonListener).toBe(true);
    });

    appPluginState.triggerBackButton();

    await waitFor(() => {
      expect(appPluginState.exitAppCalls).toBe(1);
    });
  });

  it('opens a clear visual picker and calls native camera or album explicitly', async () => {
    renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /视觉求助|拍摄创口/i }));

    expect(await screen.findByRole('button', { name: '拍摄' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '从相册导入' })).toBeInTheDocument();
    expect(cameraPluginState.getPhotoMock).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: '从相册导入' }));

    await waitFor(() => {
      expect(cameraPluginState.getPhotoMock).toHaveBeenCalledWith(expect.objectContaining({
        source: 'photos',
        resultType: 'base64',
      }));
    });

    const uploadedPreview = await screen.findByRole('img', { name: /视觉求助/i });
    expect(uploadedPreview).toHaveAttribute('src', 'data:image/jpeg;base64,ZmFrZS1pbWFnZS1ieXRlcw==');
    expect(screen.getByText(/视觉求助 \/ 拍摄创口 - 从相册导入/)).toBeInTheDocument();
    expect(screen.queryByText(/请将创口、不明植物或动物置于框内/)).not.toBeInTheDocument();
  });

  it('renders a captured camera photo inside the chat before visual analysis finishes', async () => {
    renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /视觉求助|拍摄创口/i }));
    fireEvent.click(await screen.findByRole('button', { name: '拍摄' }));

    await waitFor(() => {
      expect(cameraPluginState.getPhotoMock).toHaveBeenCalledWith(expect.objectContaining({
        source: 'camera',
        resultType: 'base64',
      }));
    });

    const capturedPreview = await screen.findByRole('img', { name: /视觉求助/i });
    expect(capturedPreview).toHaveAttribute('src', 'data:image/jpeg;base64,ZmFrZS1pbWFnZS1ieXRlcw==');
    expect(screen.getByText(/视觉求助 \/ 拍摄创口 - 拍摄/)).toBeInTheDocument();
  });

  it('ignores swipes that do not start from the leading edge', async () => {
    const { container } = renderApp('zh-CN');

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    expect(await screen.findByText(/尽量用湿布或多层布料遮住口鼻/, {}, { timeout: 8000 })).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.queryByText(/正在生成建议\.\.\./)).not.toBeInTheDocument();
    }, { timeout: 8000 });

    const appContainer = container.querySelector('.container');
    expect(appContainer).not.toBeNull();

    fireEvent.touchStart(appContainer as Element, {
      touches: [{ clientX: 120, clientY: 180 }],
    });
    fireEvent.touchMove(appContainer as Element, {
      touches: [{ clientX: 240, clientY: 186 }],
      cancelable: true,
    });
    fireEvent.touchEnd(appContainer as Element, {
      changedTouches: [{ clientX: 240, clientY: 186 }],
    });

    expect(screen.queryByRole('heading', { name: /先活下来，再想别的/ })).not.toBeInTheDocument();
    expect(screen.getByText(/尽量用湿布或多层布料遮住口鼻/)).toBeInTheDocument();
  });

  it('stops auto-retrying model init after a hard native failure', async () => {
    let loadAttempts = 0;
    const mockBridge = createMockBeaconBridge();
    mockBridge.listModels = async () => [
      {
        id: 'gemma-4-e2b',
        tier: 'e2b',
        name: 'Gemma 4 E2B',
        localPath: 'models/gemma-4-E2B-it.litertlm',
        sizeLabel: '2B / Survival Baseline',
        isLoaded: false,
        isDownloaded: true,
        downloadStatus: 'succeeded',
        artifactFormat: 'litertlm',
        runtimeStack: 'litert-lm-c-api',
        preferredBackend: 'auto-real',
        capabilityClass: 'supported',
        supportedDeviceClass: 'iphone_primary',
      },
    ];
    mockBridge.loadModel = async () => {
      loadAttempts += 1;
      throw new Error('This iPhone has 4.0 GB RAM, below the current Gemma 4 E2B iOS baseline of 6 GB.');
    };
    window.beaconBridge = mockBridge;

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    expect((await screen.findAllByText(/6 GB RAM|内存低于 6GB/)).length).toBeGreaterThan(0);
    expect(loadAttempts).toBe(1);

    await new Promise((resolve) => window.setTimeout(resolve, 1800));

    expect(loadAttempts).toBe(1);
  });

  it('keeps the full streamed text and hides matched categories metadata', async () => {
    const mockBridge = createMockBeaconBridge();
    mockBridge.initialize = async () => undefined;
    mockBridge.triageStream = async function* () {
      yield { delta: '先远离浓烟并' };
      yield { delta: '压低身体移动。' };

      const finalResponse: TriageResponse = {
        summary: '先远离浓烟。',
        steps: ['压低身体移动。'],
        disclaimer: '此回答由本地模型结合离线权威证据生成；恢复通信后仍建议尽快联系专业救援。',
        isKnowledgeBacked: true,
        guidanceMode: 'grounded',
        evidence: {
          authoritative: [
            {
              id: 'ready-fire',
              sourceId: 'ready-fire',
              title: 'Building Fire',
              source: 'Ready.gov',
              summary: 'Fire emergency',
              steps: ['Stay low'],
              contraindications: [],
              escalation: 'Call emergency services',
              strategy: 'directRule',
              score: 1,
            },
          ],
          supporting: [],
          matchedCategories: ['火场被困'],
          queryTerms: ['fire'],
        },
        usedProfileName: 'gemma-4-e2b-balanced',
      };

      yield { delta: '', done: true, final: finalResponse };
    };
    window.beaconBridge = mockBridge;
    window.localStorage.setItem('beacon_locale', 'zh-CN');

    render(
      <I18nProvider>
        <App />
      </I18nProvider>,
    );

    fireEvent.click(await screen.findByRole('button', { name: /火场被困/i }));
    await new Promise((resolve) => window.setTimeout(resolve, 220));

    expect(await screen.findByText('先远离浓烟并压低身体移动。', {}, { timeout: 2000 })).toBeInTheDocument();
    await waitFor(() => {
      expect(screen.getByText('权威来源')).toBeInTheDocument();
    });
    expect(screen.queryByText('命中类别')).toBeNull();
  });
});
