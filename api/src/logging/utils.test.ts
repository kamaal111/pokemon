import { PassThrough } from 'node:stream';

import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { requestId } from 'hono/request-id';
import pino from 'pino';
import { describe, expect, test, vi } from 'vitest';
import z from 'zod';

import { REQUEST_ID_HEADER_NAME } from '@/constants/common';
import type { HonoEnvironment } from '@/context';
import { SERVER_MODES } from '@/env';
import { InvalidPayload, InvalidValidation } from '@/exceptions';
import loggingMiddleware from './middleware';
import {
  createServerLogger,
  getValidationIssuePaths,
  getValidationIssues,
  handleServerError,
  logError,
  logInfo,
  logWarn,
  sanitizeLogRecord,
  serializeError,
} from './utils';

function createSilentLogger() {
  const stream = new PassThrough();
  stream.resume();

  return pino({ level: 'trace' }, stream);
}

describe('logging utilities', () => {
  test('sanitizes structured log records to scalar values and scalar arrays', () => {
    expect(
      sanitizeLogRecord({
        string: 'value',
        number: 1,
        boolean: false,
        empty: null,
        array: ['value', 1, true, null, { nested: true }],
        object: { nested: true },
        objectArray: [{ nested: true }],
      }),
    ).toEqual({
      string: 'value',
      number: 1,
      boolean: false,
      empty: null,
      array: ['value', 1, true, null],
      object: undefined,
      objectArray: undefined,
    });
  });

  test('logs sanitized info, warnings, and errors', () => {
    const logger = createSilentLogger();

    logInfo(logger, { event: 'info.event' });
    logWarn(logger, { event: 'warn.event' }, 'warning');
    logError(logger, { event: 'error.event' }, undefined);
    logError(logger, { event: 'fatal.event' }, null, 'fatal', 'fatal');
    logError(logger, { event: 'primitive.error' }, 'failed');
    logError(logger, { event: 'number.error' }, 123);
    logError(logger, { event: 'boolean.error' }, true);
    logError(logger, { event: 'object.error' }, { problem: true });
    logError(logger, { event: 'error.cause.error' }, new Error('wrapped', { cause: 'root' }));
    logError(logger, { event: 'error.cause.object' }, new Error('wrapped', { cause: {} }));
    logError(
      logger,
      { event: 'error.cause.native' },
      new Error('wrapped', { cause: new Error('root') }),
    );

    expect(logger.bindings()).toEqual({});
  });

  test('serializes all supported error shapes', () => {
    expect(serializeError(undefined)).toBeUndefined();
    expect(serializeError(null)).toBeUndefined();
    expect(serializeError('failed')).toMatchObject({
      error_name: 'string',
      error_details: 'failed',
    });
    expect(serializeError(123)).toMatchObject({
      error_name: 'number',
      error_details: '123',
    });
    expect(serializeError(false)).toMatchObject({
      error_name: 'boolean',
      error_details: 'false',
    });
    expect(serializeError({ failed: true })).toMatchObject({
      error_name: 'object',
      error_details: 'Non-Error value thrown',
    });
    expect(serializeError(new Error('wrapped', { cause: 123 }))).toMatchObject({
      error_name: 'Error',
      error_message: 'wrapped',
      error_cause_name: 'number',
      error_cause_message: '123',
    });

    const errorWithUnnamedConstructor = new Error('unnamed');
    Object.defineProperty(errorWithUnnamedConstructor, 'constructor', { value: { name: '' } });
    const causeWithUnnamedConstructor = new Error('cause');
    Object.defineProperty(causeWithUnnamedConstructor, 'constructor', { value: { name: '' } });

    expect(serializeError(errorWithUnnamedConstructor)).toMatchObject({
      error_name: 'Error',
    });
    expect(
      serializeError(new Error('wrapped', { cause: causeWithUnnamedConstructor })),
    ).toMatchObject({
      error_cause_name: 'Error',
    });
  });

  test('normalizes validation issue context for logging', () => {
    expect(getValidationIssues(null)).toEqual([]);
    expect(getValidationIssues({ validations: 'invalid' })).toEqual([]);
    expect(
      getValidationIssues({
        validations: [
          null,
          'invalid',
          {},
          { path: null },
          { path: ['name', 0] },
          { path: ['name', {}] },
        ],
      }),
    ).toEqual([{}, { path: null }, { path: ['name', 0] }]);
    expect(
      getValidationIssuePaths([{}, { path: null }, { path: [] }, { path: ['name', 0] }]),
    ).toEqual(['<root>', '<root>', '<root>', 'name.0']);
  });

  test('creates a logger with explicit options and destination overrides', () => {
    const stream = new PassThrough();
    stream.resume();

    const logger = createServerLogger({
      destination: stream,
      level: 'silent',
      mode: SERVER_MODES.TEST,
      pretty: true,
    });

    expect(logger.bindings()).toMatchObject({
      service: 'pokemon-api',
      component: 'server',
      mode: SERVER_MODES.TEST,
    });
  });

  test('creates a pretty logger when debug mode is enabled during module initialization', async () => {
    vi.resetModules();
    vi.stubEnv('DEBUG', 'true');
    vi.stubEnv('MODE', SERVER_MODES.TEST);

    await expect(import('./utils')).resolves.toMatchObject({
      createRequestLogger: expect.any(Function),
    });

    vi.unstubAllEnvs();
  });

  test('maps typed exceptions through the shared error handler', async () => {
    const app = new Hono<HonoEnvironment>()
      .onError(handleServerError)
      .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
      .use(loggingMiddleware());

    app.get('/invalid-payload', (c) => {
      throw new InvalidPayload(c, { message: 'Bad thing', context: { reason: 'test' } });
    });

    app.get('/invalid-validation', (c) => {
      const parsedPayload = z.object({ name: z.string().min(3) }).safeParse({ name: '' });
      if (!parsedPayload.success) {
        throw new InvalidValidation(c, parsedPayload.error);
      }

      return c.json({ ok: true });
    });

    app.get('/http-exception', () => {
      throw new HTTPException(423, { message: 'Locked thing' });
    });

    const invalidPayloadResponse = await app.request('http://localhost/invalid-payload');
    const invalidValidationResponse = await app.request('http://localhost/invalid-validation');
    const httpExceptionResponse = await app.request('http://localhost/http-exception');

    expect(invalidPayloadResponse.status).toBe(400);
    await expect(invalidPayloadResponse.json()).resolves.toEqual({
      message: 'Bad thing',
      code: 'INVALID_PAYLOAD',
      context: { reason: 'test' },
    });

    expect(invalidValidationResponse.status).toBe(400);
    await expect(invalidValidationResponse.json()).resolves.toMatchObject({
      message: 'Invalid payload',
      code: 'INVALID_PAYLOAD',
    });

    expect(httpExceptionResponse.status).toBe(423);
    await expect(httpExceptionResponse.text()).resolves.toBe('Locked thing');
  });
});
