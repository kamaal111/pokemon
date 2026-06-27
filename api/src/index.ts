import { showRoutes } from 'hono/dev';

import { IS_DEBUG, IS_TEST } from './env.ts';
import startServer from './server.ts';
import createApp from './app.ts';
import { getDatabaseConfig } from './database/index.ts';
import { getCardSetsSeedDependencies, getPokedexSeedDependencies } from './seed/index.ts';

if (import.meta.main && !IS_TEST) {
  const app = createApp({
    databaseConfig: getDatabaseConfig(),
    pokedexSeedDependencies: getPokedexSeedDependencies({}),
    cardSetsSeedDependencies: getCardSetsSeedDependencies({}),
  });

  if (IS_DEBUG) {
    showRoutes(app, { verbose: false });
  }

  startServer(app);
}
