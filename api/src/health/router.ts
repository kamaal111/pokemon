import { Hono } from 'hono';

import type { HonoEnvironment } from '../context.ts';

function healthRouter() {
  const router = new Hono<HonoEnvironment>();

  return router.get('/ping', (c) => c.json({ message: 'PONG' }));
}

export default healthRouter;
