import assert from 'node:assert/strict';

import type { ErrorHandler } from 'hono';
import type { RequestIdVariables } from 'hono/request-id';
import { HTTPException } from 'hono/http-exception';
import pino from 'pino';
import type { DestinationStream, LevelWithSilent, Logger, LoggerOptions } from 'pino';

import type { LogLevel, ServerMode } from '@/env';
import env, { IS_DEBUG } from '@/env';
import packageJson from '../../package.json';
import type { LogBindings, LogScalar, LogValue } from './types';
import type { HonoContext, HonoEnvironment } from '@/context';
import { getRequestLogger, getRouteForLog, markRequestFailed } from './http';
import { STATUS_CODES } from '@/constants/http';
import { APIException, InvalidValidation } from '@/exceptions';

interface CreateLoggerOptions {
  destination?: DestinationStream;
  level?: LevelWithSilent;
  mode?: ServerMode;
  pretty?: boolean;
}

interface BaseLogFields {
  event: string;
  mode?: ServerMode;
  outcome?: 'failure' | 'success';
  request_id?: RequestIdVariables['requestId'];
  method?: string;
  path?: string;
  url?: string;
  route?: string;
  status_code?: number;
  duration_ms?: number;
  user_id?: string;
  error_code?: string;
  error_name?: string;
  cache_status?: 'hit' | 'miss' | 'set' | 'skip';
  result_count?: number;
  stored_count?: number;
  transaction_type?: string;
}

type LogFields = BaseLogFields & LogBindings;

const SERVICE_NAME = packageJson.name;
assert(SERVICE_NAME);

const DEFAULT_COMPONENT = 'server';
const REQUEST_COMPONENT = 'http';

let rootLogger = createServerLogger();

export function createRequestLogger(fields: {
  requestId: string;
  method: string;
  path: string;
  url: string;
  route: string;
  mode: ServerMode;
}) {
  return childLogger(rootLogger, {
    component: REQUEST_COMPONENT,
    request_id: fields.requestId,
    method: fields.method,
    path: fields.path,
    url: fields.url,
    route: fields.route,
    mode: fields.mode,
  });
}

export function childLogger(logger: Logger, bindings: LogBindings) {
  return logger.child(sanitizeLogRecord(bindings));
}

export function sanitizeLogRecord(record: Record<string, unknown>): LogBindings {
  return Object.fromEntries(
    Object.entries(record).map(([key, value]) => [key, sanitizeLogValue(value)]),
  );
}

export function logEvent(logger: Logger, level: LogLevel, fields: LogFields, message?: string) {
  logger[level](sanitizeLogRecord(fields), message);
}

export function logInfo(logger: Logger, fields: LogFields, message?: string) {
  logEvent(logger, 'info', fields, message);
}

export function logWarn(logger: Logger, fields: LogFields, message?: string) {
  logEvent(logger, 'warn', fields, message);
}

export function logError(
  logger: Logger,
  fields: LogFields,
  error?: unknown,
  message?: string,
  level: Extract<LogLevel, 'error' | 'fatal'> = 'error',
) {
  const errorFields = error == null ? undefined : serializeError(error);
  const mergedFields = errorFields == null ? fields : { ...fields, ...errorFields };
  logger[level](sanitizeLogRecord(mergedFields), message);
}

export function serializeError(error: unknown): Record<string, unknown> | undefined {
  if (error == null) {
    return undefined;
  }

  if (error instanceof Error) {
    return {
      error_name: error.constructor.name || error.name,
      error_message: error.message,
      error_stack: error.stack,
      error_cause_name: getErrorCauseName(error),
      error_cause_message: getErrorCauseMessage(error),
    };
  }

  return {
    error_name: typeof error,
    error_details:
      typeof error === 'string' || typeof error === 'number' || typeof error === 'boolean'
        ? `${error}`
        : 'Non-Error value thrown',
  };
}

export const handleServerError = ((err, ctx: HonoContext) => {
  const logger = getRequestLogger(ctx);

  if (err instanceof InvalidValidation) {
    const validationIssues = getValidationIssues(err.context);
    logWarn(logger, {
      event: 'request.validation.failed',
      route: getRouteForLog(ctx),
      status_code: err.status,
      outcome: 'failure',
      error_code: 'INVALID_PAYLOAD',
      error_name: err.name,
      validation_issue_count: validationIssues.length,
      validation_issue_paths: getValidationIssuePaths(validationIssues),
    });

    return err.getResponse();
  }

  if (err instanceof APIException) {
    logWarn(logger, {
      event: 'request.error',
      route: getRouteForLog(ctx),
      status_code: err.status,
      outcome: 'failure',
      error_code: err.code,
      error_name: err.name,
    });

    return err.getResponse();
  }

  if (err instanceof HTTPException) {
    logWarn(logger, {
      event: 'request.error',
      route: getRouteForLog(ctx),
      status_code: err.status,
      outcome: 'failure',
      error_name: err.name,
    });

    return err.getResponse();
  }

  markRequestFailed(ctx);
  logError(
    logger,
    {
      event: 'request.failed',
      route: getRouteForLog(ctx),
      status_code: STATUS_CODES.INTERNAL_SERVER_ERROR,
      outcome: 'failure',
      error_code: 'INTERNAL_SERVER_ERROR',
    },
    err,
  );

  return ctx.json(
    { message: 'Something went wrong', code: 'INTERNAL_SERVER_ERROR' },
    STATUS_CODES.INTERNAL_SERVER_ERROR,
  );
}) satisfies ErrorHandler<HonoEnvironment>;

export function getValidationIssuePaths(validations: ValidationIssue[]) {
  return validations.map((issue) => {
    if (
      issue == null ||
      typeof issue !== 'object' ||
      !('path' in issue) ||
      !Array.isArray(issue.path)
    ) {
      return '<root>';
    }

    const path = issue.path.map((segment: string | number) => String(segment)).join('.');
    return path.length > 0 ? path : '<root>';
  });
}

interface ValidationIssue {
  path?: (string | number)[] | null;
}

export function getValidationIssues(context: unknown): ValidationIssue[] {
  if (context == null || typeof context !== 'object' || !('validations' in context)) {
    return [];
  }

  const validations = context.validations;
  return Array.isArray(validations) ? validations.filter(isValidationIssue) : [];
}

function isValidationIssue(value: unknown): value is ValidationIssue {
  if (value == null || typeof value !== 'object') {
    return false;
  }

  if (!('path' in value) || value.path == null) {
    return true;
  }

  return (
    Array.isArray(value.path) &&
    value.path.every((segment) => typeof segment === 'string' || typeof segment === 'number')
  );
}

function getErrorCauseName(error: Error): string | undefined {
  const cause = error.cause;
  if (cause == null) {
    return undefined;
  }

  if (cause instanceof Error) {
    return cause.constructor.name || cause.name;
  }

  return typeof cause;
}

function getErrorCauseMessage(error: Error): string | undefined {
  const cause = error.cause;
  if (cause == null) {
    return undefined;
  }

  if (cause instanceof Error) {
    return cause.message;
  }

  if (typeof cause === 'string' || typeof cause === 'number' || typeof cause === 'boolean') {
    return cause.toString();
  }

  return undefined;
}

function sanitizeLogValue(value: unknown): LogValue | undefined {
  if (
    value == null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }

  if (Array.isArray(value)) {
    const sanitizedItems = value.flatMap((item) => {
      const sanitizedItem = sanitizeArrayItem(item);
      return sanitizedItem === undefined ? [] : [sanitizedItem];
    });
    return sanitizedItems.length > 0 ? sanitizedItems : undefined;
  }

  return undefined;
}

function sanitizeArrayItem(value: unknown): LogScalar | undefined {
  if (
    value == null ||
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return value;
  }

  return undefined;
}

export function createServerLogger(options: CreateLoggerOptions = {}) {
  const destination = options.destination ?? createDestination(options.pretty ?? IS_DEBUG);
  const loggerOptions = createLoggerOptions(
    options.level ?? env.LOG_LEVEL,
    options.mode ?? env.MODE,
  );

  return pino(loggerOptions, destination);
}

function createLoggerOptions(level: LevelWithSilent, mode: ServerMode): LoggerOptions {
  return {
    level,
    base: {
      service: SERVICE_NAME,
      component: DEFAULT_COMPONENT,
      mode,
    },
    redact: {
      paths: [
        'authorization',
        'Authorization',
        'cookie',
        'Cookie',
        'cookies',
        'req.headers.authorization',
        'req.headers.Authorization',
        'req.headers.cookie',
        'req.headers.Cookie',
        'headers.authorization',
        'headers.Authorization',
        'headers.cookie',
        'headers.Cookie',
        'response.headers.set-cookie',
        'response.headers.Set-Cookie',
        'jwt',
        'token',
        'sessionToken',
        'accessToken',
        'refreshToken',
        'body',
        'request.body',
        'response.body',
      ],
      censor: '[Redacted]',
    },
  };
}

function createDestination(pretty: boolean) {
  if (pretty) {
    return pino.transport({
      target: 'pino-pretty',
      options: {
        colorize: true,
        ignore: 'pid,hostname',
      },
    });
  }

  return pino.destination({ sync: true });
}
