import { describe, expect, test } from 'vitest';
import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import pino from 'pino';

import { REQUEST_ID_HEADER_NAME } from '@/constants/common';
import type { HonoEnvironment } from '@/context';
import { getLoggerBindings, getRequestLogger } from './http';

describe('http logging helpers', () => {
  test('initializes a request logger lazily when middleware has not set one', async () => {
    const app = new Hono<HonoEnvironment>()
      .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
      .get('/lazy-logger', (c) => {
        const logger = getRequestLogger(c);

        return c.json({ requestId: logger.bindings().request_id });
      });

    const response = await app.request('http://localhost/lazy-logger', {
      headers: { [REQUEST_ID_HEADER_NAME]: 'request-1' },
    });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ requestId: 'request-1' });
  });

  test('returns empty bindings when a logger exposes invalid bindings', () => {
    const logger = { bindings: () => null };
    const arrayLogger = { bindings: () => ['invalid'] };

    expect(getLoggerBindings(logger)).toEqual({});
    expect(getLoggerBindings(arrayLogger)).toEqual({});
  });

  test('binds the authenticated user id to the request logger when needed', async () => {
    const app = new Hono<HonoEnvironment>()
      .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
      .get('/session-logger', (c) => {
        c.set('session', { user: { id: 'user-1' } });
        const logger = getRequestLogger(c);

        return c.json({ userId: logger.bindings().user_id });
      });

    const response = await app.request('http://localhost/session-logger');

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ userId: 'user-1' });
  });

  test('reuses an existing user binding', async () => {
    const app = new Hono<HonoEnvironment>()
      .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
      .get('/logger/reuse', (c) => {
        c.set('logger', pino().child({ user_id: 'existing-user' }));
        c.set('session', { user: { id: 'new-user' } });
        const logger = getRequestLogger(c);

        return c.json({ userId: logger.bindings().user_id });
      });

    const response = await app.request('http://localhost/logger/reuse');

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ userId: 'existing-user' });
  });

  test('falls back to the request path for wildcard routes', async () => {
    const app = new Hono<HonoEnvironment>()
      .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
      .get('/wild/*', (c) => {
        const logger = getRequestLogger(c);

        return c.json({ route: logger.bindings().route });
      });

    const response = await app.request('http://localhost/wild/example');

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ route: '/wild/example' });
  });
});
