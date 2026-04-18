import { describe, expect, it } from 'vitest';
import { createMockBeaconBridge } from './mockBridge';

describe('MockBeaconBridge', () => {
  it('returns grounded response for panic shortcuts', async () => {
    const bridge = createMockBeaconBridge();
    const response = await bridge.triage({
      userText: '我在火场里有浓烟',
      categoryHint: '火场被困',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-mock-fire',
    });

    expect(response.guidanceMode).toBe('grounded');
    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative[0]?.source).toContain('Ready.gov');
  });

  it('still returns AI guidance when evidence is weak', async () => {
    const bridge = createMockBeaconBridge();
    const response = await bridge.triage({
      userText: 'qzmtvx blorf narpel zeek',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-mock-limited',
    });

    expect(response.guidanceMode).toBe('grounded');
    expect(response.isKnowledgeBacked).toBe(false);
    expect(response.summary).not.toContain('AI 已介入分析');
    expect(response.steps.length).toBeGreaterThan(0);
  });

  it('toggles sos and returns nearby node count', async () => {
    const bridge = createMockBeaconBridge();
    const active = await bridge.toggleSos({
      summary: '腿部开放性骨折，需要离线支援',
      locale: 'zh-CN',
    });
    const stopped = await bridge.toggleSos({
      summary: '腿部开放性骨折，需要离线支援',
      locale: 'zh-CN',
    });

    expect(active.active).toBe(true);
    expect(active.connectedPeers).toBeGreaterThan(0);
    expect(stopped.active).toBe(false);
  });

  it('localizes low-battery warnings from warning codes', async () => {
    const bridge = createMockBeaconBridge();
    await bridge.setPowerMode('doomsday');
    await bridge.triage({
      userText: 'Need help in smoke',
      powerMode: 'doomsday',
      locale: 'ja',
      sessionId: 'session-mock-battery',
    });

    const battery = await bridge.getBatteryStatus();
    expect(battery.warningCode).toBe('battery.low_power_emergency');
    expect(battery.warning).toContain('バッテリー');
  });

  it('exposes runtime diagnostics for verification hooks', async () => {
    const bridge = createMockBeaconBridge();
    const diagnostics = await bridge.getRuntimeDiagnostics();

    expect(diagnostics.platform).toBe('web');
    expect(diagnostics.activeBackend).toBe('mock');
    expect(diagnostics.acceleratorFamily).toBe('unknown');
  });
});
