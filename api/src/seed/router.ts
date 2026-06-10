import { Hono } from 'hono';

import type { HonoEnvironment } from '../context.ts';
import { databaseMiddleware, type DatabaseMiddlewareDependencies } from '../database/middleware.ts';
import { allowedModes } from '../middleware.ts';
import { SERVER_MODES } from '../env.ts';
import seedCardSetsRoute from './routes/seed-card-sets.ts';
import seedPokedexRoute from './routes/seed-pokedex.ts';
import type { SeedDependencies } from './service.ts';

export type SeedRouterDependencies = DatabaseMiddlewareDependencies & {
  pokedexSeedDependencies: SeedDependencies;
  cardSetsSeedDependencies: SeedDependencies;
};

function seedRouter(dependencies: SeedRouterDependencies) {
  const router = new Hono<HonoEnvironment>();

  return router
    .use(allowedModes(SERVER_MODES.SEED))
    .use(databaseMiddleware(dependencies))
    .post(...seedCardSetsRoute(dependencies))
    .post(...seedPokedexRoute(dependencies));
}

export default seedRouter;
