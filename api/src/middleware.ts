import { createMiddleware } from 'hono/factory';

import type { HonoVariables } from './context';
import env, { SERVER_MODES, type ServerMode } from './env';
import { NotFound } from './exceptions';

const { MODE } = env;

export function allowedModes(...modes: ServerMode[]) {
  return createMiddleware<{ Variables: HonoVariables }>(async (c, next) => {
    if (MODE !== SERVER_MODES.TEST && !modes.includes(MODE)) {
      throw new NotFound(c);
    }

    await next();
  });
}
