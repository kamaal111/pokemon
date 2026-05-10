import { createMiddleware } from 'hono/factory';

import type { HonoVariables } from '../context.ts';
import type { DatabaseConfig } from './config.ts';
import { createDatabase } from './utils.ts';

export interface DatabaseMiddlewareDependencies {
  databaseConfig: DatabaseConfig;
}

export function databaseMiddleware(dependencies: DatabaseMiddlewareDependencies) {
  return createMiddleware<{ Variables: HonoVariables }>(async (c, next) => {
    const database = await createDatabase(dependencies.databaseConfig);

    c.set('database', database);

    try {
      await next();
    } finally {
      database.close();
    }
  });
}
