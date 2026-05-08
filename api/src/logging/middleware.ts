import type { Next } from 'hono';

import type { HonoContext } from '@/context';
import env from '@/env';
import {
  getRequestLogger,
  getRouteForLog,
  hasRequestFailed,
  initializeRequestLogger,
} from './http';
import { logInfo } from './utils';
import { STATUS_CODES } from '@/constants/http';

function loggingMiddleware() {
  return async (c: HonoContext, next: Next) => {
    const logger = initializeRequestLogger(c, env.MODE);
    const startedAt = performance.now();

    logInfo(logger, { event: 'request.started' });

    await next();

    if (hasRequestFailed(c)) {
      return;
    }

    logInfo(getRequestLogger(c), {
      event: 'request.completed',
      route: getRouteForLog(c),
      status_code: c.res.status,
      duration_ms: roundDurationMs(performance.now() - startedAt),
      outcome: c.res.status >= STATUS_CODES.BAD_REQUEST ? 'failure' : 'success',
    });
  };
}

function roundDurationMs(durationMs: number) {
  return Math.round(durationMs * 100) / 100;
}

export default loggingMiddleware;
