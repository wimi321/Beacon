import { describe, expect, it } from 'vitest';
import {
  attachTriageSession,
  consumeTriageSessionReset,
  createTriageSessionState,
  resetTriageSessionState,
} from './session';

describe('triage session helpers', () => {
  it('marks the first request in a session as resettable new context', () => {
    const session = createTriageSessionState();
    const request = attachTriageSession(
      {
        userText: 'Need help',
        powerMode: 'normal',
        locale: 'en',
      },
      session,
    );

    expect(request.sessionId).toMatch(/^session-/);
    expect(request.resetContext).toBe(true);
  });

  it('consumes the reset marker without rotating the hot session id', () => {
    const session = createTriageSessionState();
    const next = consumeTriageSessionReset(session);

    expect(next.sessionId).toBe(session.sessionId);
    expect(next.resetContext).toBe(false);
  });

  it('rotates to a brand new session after clear chat', () => {
    const session = createTriageSessionState();
    const reset = resetTriageSessionState();

    expect(reset.sessionId).not.toBe(session.sessionId);
    expect(reset.resetContext).toBe(true);
  });
});
