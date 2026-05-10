import url from 'node:url';

import { describe, expect, vi } from 'vitest';

import { integrationTest as test } from '../../tests/fixtures.ts';
import { SERVER_MODES } from '../../env.ts';
import { countPokemonSpecies } from '../repository.ts';
import { buildSpeciesListingUrl } from '../pokeapi.ts';
import { createSpeciesDetail, jsonResponse } from '../../tests/utils.ts';

const TEST_UPSTREAM_SPECIES_COUNT = 45;

describe('POST /seed/pokedex', () => {
  test('returns the number of newly seeded pokemon species', async ({ apiMock, app, database }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    const response = await app.request('http://localhost/seed/pokedex', {
      method: 'POST',
    });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ saved: TEST_UPSTREAM_SPECIES_COUNT });
    await expect(countPokemonSpecies(database)).resolves.toBe(TEST_UPSTREAM_SPECIES_COUNT);
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

  test('returns an internal server error when an upstream detail payload is invalid', async ({
    apiMock,
    app,
    database,
  }) => {
    apiMock.mockUrl(
      'https://pokeapi.co/api/v2/pokemon-species/1/',
      jsonResponse({ ...createSpeciesDetail(1), name: '' }),
    );

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

  test('returns a structured not found response when the seed route is disabled by mode', async ({
    databasePath,
    seedDependencies,
  }) => {
    vi.resetModules();
    vi.stubEnv('MODE', SERVER_MODES.API);
    try {
      const { default: createApp } = await import('../../app.ts');
      const apiModeApp = createApp({
        databaseConfig: { url: url.pathToFileURL(databasePath).toString() },
        pokedexSeedDependencies: seedDependencies,
      });

      const response = await apiModeApp.request('http://localhost/seed/pokedex', {
        method: 'POST',
      });

      expect(response.status).toBe(404);
      await expect(response.json()).resolves.toEqual({
        message: 'Not found',
        code: 'NOT_FOUND',
      });
    } finally {
      vi.unstubAllEnvs();
    }
  });
});
