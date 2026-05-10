import { routePath } from 'hono/route';
import type { Logger } from 'pino';

import type { HonoContext } from '../context.ts';
import type { ServerMode } from '../env.ts';
import { childLogger, createRequestLogger } from './utils.ts';
import env from '../env.ts';

export function initializeRequestLogger(c: HonoContext, mode: ServerMode) {
  const logger = createRequestLogger({
    requestId: c.get('requestId'),
    method: c.req.method,
    path: c.req.path,
    url: c.req.url,
    route: getMatchedRoutePath(c),
    mode,
  });

  c.set('logger', logger);
  return logger;
}

export function markRequestFailed(c: HonoContext) {
  c.set('requestFailed', true);
}

export function hasRequestFailed(c: HonoContext) {
  return c.get('requestFailed') === true;
}

export function getRouteForLog(c: HonoContext) {
  return getMatchedRoutePath(c);
}

export function getRequestLogger(c: HonoContext) {
  const existingLogger = c.get('logger') ?? initializeRequestLogger(c, env.MODE);
  return bindAuthenticatedUserIdFromContext(c, existingLogger);
}

export function getLoggerBindings(logger: { bindings(): unknown }): Record<string, unknown> {
  const bindings = logger.bindings();
  return isRecord(bindings) ? bindings : {};
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function bindAuthenticatedUserIdFromContext(c: HonoContext, logger: Logger) {
  const existingUserId = getLoggerBindings(logger).user_id;
  if (typeof existingUserId === 'string' && existingUserId.length > 0) {
    return logger;
  }

  const session = c.get('session');
  const userId = session?.user.id;
  if (typeof userId !== 'string' || userId.length === 0) {
    return logger;
  }

  const loggerWithUserId = childLogger(logger, { user_id: userId });
  c.set('logger', loggerWithUserId);

  return loggerWithUserId;
}

function getMatchedRoutePath(c: HonoContext) {
  const matchedRoutePath = routePath(c);
  return matchedRoutePath.length > 0 && !matchedRoutePath.includes('*')
    ? matchedRoutePath
    : c.req.path;
}
