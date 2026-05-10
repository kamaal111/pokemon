import { Hono } from 'hono';
import { requestId } from 'hono/request-id';
import { compress } from 'hono/compress';
import { secureHeaders } from 'hono/secure-headers';
import { etag } from 'hono/etag';

import { loggingMiddleware, handleServerError } from './logging/index.ts';
import { REQUEST_ID_HEADER_NAME } from './constants/common.ts';
import type { HonoEnvironment } from './context.ts';
import { HEALTH_ROUTER_NAME, healthRouter } from './health/index.ts';
import { theWorld } from './middleware.ts';
import { SEED_ROUTER_NAME, seedRouter } from './seed/index.ts';
import type { SeedRouterDependencies } from './seed/router.ts';
import type { DatabaseMiddlewareDependencies } from './database/middleware.ts';

export type AppDependencies = DatabaseMiddlewareDependencies & SeedRouterDependencies;

function createApp(dependencies: AppDependencies) {
  const app = new Hono<HonoEnvironment>()
    .onError(handleServerError)
    .use(requestId({ headerName: REQUEST_ID_HEADER_NAME }))
    .use(compress())
    .use(secureHeaders())
    .use(etag())
    .use(theWorld())
    .use(loggingMiddleware())
    .route(HEALTH_ROUTER_NAME, healthRouter())
    .route(SEED_ROUTER_NAME, seedRouter(dependencies));

  return app;
}

export default createApp;
