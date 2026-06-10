import url from 'node:url';

import { describe, expect, vi } from 'vitest';

import { integrationTest as test } from '../../tests/fixtures.ts';
import { jsonResponse } from '../../tests/utils.ts';
import { SERVER_MODES } from '../../env.ts';
import { LIMITLESS_JP_CARD_SETS_URL, POKEMON_TCG_API_CARD_SETS_URL } from '../constants.ts';
import { countPokemonCardSets } from '../repository.ts';

const LIMITLESS_SET_INDEX_HTML = `
  <table>
    <tr>
      <td><a href="/cards/jp/M2a">Mega Dream ex M2a</a></td>
      <td><a href="/cards/jp/M2a">28 Nov 25</a></td>
      <td><a href="/cards/jp/M2a">250</a></td>
    </tr>
    <tr>
      <td><a href="/cards/jp/SV8a">Terastal Fest ex SV8a</a></td>
      <td><a href="/cards/jp/SV8a">06 Dec 24</a></td>
      <td><a href="/cards/jp/SV8a">237</a></td>
    </tr>
  </table>
`;

const POKEMON_TCG_API_SETS_RESPONSE = {
  data: [
    {
      id: 'sv8',
      name: 'Surging Sparks',
      series: 'Scarlet & Violet',
      printedTotal: 191,
      total: 252,
      ptcgoCode: 'SSP',
      releaseDate: '2024/11/08',
    },
  ],
};

describe('POST /seed/card-sets', () => {
  test('returns the number of newly seeded pokemon card sets', async ({
    apiMock,
    app,
    database,
  }) => {
    apiMock.mockUrl(LIMITLESS_JP_CARD_SETS_URL, new Response(LIMITLESS_SET_INDEX_HTML));
    apiMock.mockUrl(POKEMON_TCG_API_CARD_SETS_URL, jsonResponse(POKEMON_TCG_API_SETS_RESPONSE));

    const response = await app.request('http://localhost/seed/card-sets', {
      method: 'POST',
    });

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ saved: 3 });
    await expect(countPokemonCardSets(database)).resolves.toBe(3);
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
        cardSetsSeedDependencies: seedDependencies,
      });

      const response = await apiModeApp.request('http://localhost/seed/card-sets', {
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
