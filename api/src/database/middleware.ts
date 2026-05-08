import { createMiddleware } from 'hono/factory';

import type { HonoVariables } from '@/context';
import type { DatabaseConfig } from './config';
import { createDatabase } from './utils';

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
