import { describe, expect } from 'vitest';

import { integrationTest as test } from './tests/fixtures.ts';

describe('api app', () => {
  test('responds to the health check through the real app middleware stack', async ({ app }) => {
    const response = await app.request('http://localhost/health/ping');

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ message: 'PONG' });
  });

  test('returns a not found response for unknown routes', async ({ app }) => {
    const response = await app.request('http://localhost/unknown');

    expect(response.status).toBe(404);
  });
});
