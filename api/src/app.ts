import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import { compress } from 'hono/compress';
import { secureHeaders } from 'hono/secure-headers';
import { etag } from 'hono/etag';

import { loggingMiddleware, handleServerError } from './logging';
import { REQUEST_ID_HEADER_NAME } from './constants/common';
import { HEALTH_ROUTER_NAME, healthRouter } from './health';
import type { HonoEnvironment } from './context';

function createApp() {
  const app = new Hono<HonoEnvironment>()
    .onError(handleServerError)
    .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
    .use(compress())
    .use(secureHeaders())
    .use(etag())
    .use(loggingMiddleware())
    .route(HEALTH_ROUTER_NAME, healthRouter());

  return app;
}

export default createApp;
