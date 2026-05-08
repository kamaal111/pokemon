import { describe, expect } from 'vitest';

import { integrationTest as test } from '@/tests/fixtures';
import { countPokemonSpecies } from '../repository';
import { buildSpeciesListingUrl } from '../pokeapi';

describe('POST /seed/pokedex', () => {
  test('returns the number of newly seeded pokemon species', async ({ app, database }) => {
    const response = await app.request('http://localhost/seed/pokedex', {
      method: 'POST',
    });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ saved: 40 });
    await expect(countPokemonSpecies(database)).resolves.toBe(40);
  });

  test('returns an internal server error when the upstream listing fetch fails', async ({
    apiMock,
    app,
    database,
  }) => {
    apiMock.mockUrl(buildSpeciesListingUrl(0), new Response('upstream failed', { status: 500 }));

    const response = await app.request('http://localhost/seed/pokedex', {
      method: 'POST',
    });

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      message: 'Something went wrong',
      code: 'INTERNAL_SERVER_ERROR',
    });
    await expect(countPokemonSpecies(database)).resolves.toBe(0);
  });
});
