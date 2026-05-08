import { showRoutes } from 'hono/dev';

import { IS_DEBUG, IS_TEST } from './env';
import startServer from './server';
import createApp from './app';
import { getDatabaseConfig } from './database';
import { getPokedexSeedDependencies } from './seed';

if (import.meta.main && !IS_TEST) {
  const app = createApp({
    databaseConfig: getDatabaseConfig(),
    pokedexSeedDependencies: getPokedexSeedDependencies({}),
  });

  if (IS_DEBUG) {
    showRoutes(app, { verbose: false });
  }

  startServer(app);
}
