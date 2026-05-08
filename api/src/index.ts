import { showRoutes } from 'hono/dev';

import { IS_DEBUG, IS_TEST } from './env';
import startServer from './server';
import createApp from './app';

if (import.meta.main && !IS_TEST) {
  const app = createApp();

  if (IS_DEBUG) {
    showRoutes(app, { verbose: false });
  }

  startServer(app);
}
