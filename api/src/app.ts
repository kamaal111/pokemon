import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import { compress } from 'hono/compress';
import { secureHeaders } from 'hono/secure-headers';
import { etag } from 'hono/etag';

import { loggingMiddleware, handleServerError } from './logging';
import { REQUEST_ID_HEADER_NAME } from './constants/common';
import type { HonoEnvironment } from './context';
import { HEALTH_ROUTER_NAME, healthRouter } from './health';
import { SEED_ROUTER_NAME, seedRouter } from './seed';

function createApp() {
  const app = new Hono<HonoEnvironment>()
    .onError(handleServerError)
    .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
    .use(compress())
    .use(secureHeaders())
    .use(etag())
    .use(loggingMiddleware())
    .route(HEALTH_ROUTER_NAME, healthRouter())
    .route(SEED_ROUTER_NAME, seedRouter());

  return app;
}

export default createApp;
