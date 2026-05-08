import { Hono } from 'hono';

import type { HonoEnvironment } from '@/context';
import { databaseMiddleware, type DatabaseMiddlewareDependencies } from '@/database/middleware';
import { allowedModes } from '@/middleware';
import { SERVER_MODES } from '@/env';
import seedPokedexRoute from './routes/seed-pokedex';
import type { SeedDependencies } from './service';

export type SeedRouterDependencies = DatabaseMiddlewareDependencies & {
  pokedexSeedDependencies: SeedDependencies;
};

function seedRouter(dependencies: SeedRouterDependencies) {
  const router = new Hono<HonoEnvironment>();

  return router
    .use(allowedModes(SERVER_MODES.SEED))
    .use(databaseMiddleware(dependencies))
    .post(...seedPokedexRoute(dependencies));
}

export default seedRouter;
