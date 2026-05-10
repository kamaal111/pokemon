import type { Context, Input } from 'hono';
import type { RequestIdVariables } from 'hono/request-id';
import type { Logger } from 'pino';

import type { SessionResponse } from './auth';
import type { Database } from './database';

export interface InjectedContext {
  database: Database;
  logger: Logger;
  theWorld: {
    now: () => Date;
  };
}

interface RequestLifecycleVariables {
  requestFailed?: boolean;
}

export type HonoVariables = RequestIdVariables &
  InjectedContext &
  RequestLifecycleVariables & { session?: SessionResponse };

export interface HonoEnvironment {
  Variables: HonoVariables;
}

export type HonoContext<
  I extends Input = Record<string, unknown>,
  P extends string = string,
> = Context<HonoEnvironment, P, I>;

export type GetHonoContextVar<Key extends keyof HonoContext['var']> = HonoContext['var'][Key];
