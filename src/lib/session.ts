import type { TriageRequest } from './types';

export type TriageSessionState = {
  sessionId: string;
  resetContext: boolean;
};

export function createTriageSessionState(): TriageSessionState {
  return {
    sessionId: `session-${crypto.randomUUID()}`,
    resetContext: true,
  };
}

export function resetTriageSessionState(): TriageSessionState {
  return createTriageSessionState();
}

export function attachTriageSession(
  request: Omit<TriageRequest, 'sessionId' | 'resetContext'>,
  session: TriageSessionState,
): TriageRequest {
  return {
    ...request,
    sessionId: session.sessionId,
    resetContext: session.resetContext,
  };
}

export function consumeTriageSessionReset(
  session: TriageSessionState,
): TriageSessionState {
  if (!session.resetContext) {
    return session;
  }

  return {
    sessionId: session.sessionId,
    resetContext: false,
  };
}
