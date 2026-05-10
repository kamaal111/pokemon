import type { Env, Hono } from 'hono';
import type { BlankEnv } from 'hono/types';
import { serve, type ServerType } from '@hono/node-server';

import env from './env.ts';

const { PORT } = env;
const SIGNALS_TO_TERMINATE_ON: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];

function startServer<E extends Env = BlankEnv>(app: Hono<E>) {
  const server = serve({ fetch: app.fetch, port: PORT }, (info) => {
    console.log(`Server is running on http://localhost:${info.port}`);
  });

  for (const signal of SIGNALS_TO_TERMINATE_ON) {
    process.on(signal, () => {
      shutdownServer(server);
    });
  }
}

function shutdownServer(server: ServerType) {
  server.close(() => {
    process.exit(0);
  });

  setTimeout(() => {
    process.exit(1);
  }, 10_000);
}

export default startServer;
