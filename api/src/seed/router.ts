import { Hono } from 'hono';

import type { HonoEnvironment } from '@/context';
import { allowedModes } from '@/middleware';
import { SERVER_MODES } from '@/env';
import seedPokedexRoute from './routes/seed-pokedex';

function seedRouter() {
  const router = new Hono<HonoEnvironment>();

  return router.use(allowedModes(SERVER_MODES.SEED)).post(...seedPokedexRoute());
}

export default seedRouter;
