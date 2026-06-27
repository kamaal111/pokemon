import { describe, expect } from 'vitest';

import { integrationTest as test } from '../tests/fixtures.ts';
import { jsonResponse } from '../tests/utils.ts';
import { pokemonCardSets } from '../db/schema/index.ts';
import { LIMITLESS_JP_CARD_SETS_URL, POKEMON_TCG_API_CARD_SETS_URL } from './constants.ts';
import { countPokemonCardSets, upsertPokemonCardSets } from './repository.ts';
import { seedPokemonCardSets } from './service.ts';

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
    <tr>
      <td><a href="/cards/jp/SV4a">Shiny Treasure ex SV4a</a></td>
      <td><a href="/cards/jp/SV4a">01 Dec 23</a></td>
      <td><a href="/cards/jp/SV4a">360</a></td>
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
    {
      id: 'sv3pt5',
      name: '151',
      series: 'Scarlet & Violet',
      printedTotal: 165,
      total: 207,
      ptcgoCode: 'MEW',
      releaseDate: '2023/09/22',
    },
  ],
};

describe('seedPokemonCardSets', () => {
  test('seeds Limitless card sets and becomes idempotent on rerun', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.mockUrl(LIMITLESS_JP_CARD_SETS_URL, () => new Response(LIMITLESS_SET_INDEX_HTML));
    apiMock.mockUrl(POKEMON_TCG_API_CARD_SETS_URL, () =>
      jsonResponse(POKEMON_TCG_API_SETS_RESPONSE),
    );

    const firstRun = await seedPokemonCardSets({ ...seedDependencies, database });
    const secondRun = await seedPokemonCardSets({ ...seedDependencies, database });
    const rows = await database.db
      .select({
        code: pokemonCardSets.code,
        name: pokemonCardSets.name,
        region: pokemonCardSets.region,
        ptcgoCode: pokemonCardSets.ptcgoCode,
      })
      .from(pokemonCardSets);

    expect(firstRun).toEqual({ saved: 5 });
    expect(secondRun).toEqual({ saved: 0 });
    await expect(countPokemonCardSets(database)).resolves.toBe(5);
    expect(
      rows.toSorted(
        (left, right) =>
          left.region.localeCompare(right.region) || left.code.localeCompare(right.code),
      ),
    ).toEqual([
      {
        code: 'sv3pt5',
        name: '151',
        region: 'en',
        ptcgoCode: 'mew',
      },
      {
        code: 'sv8',
        name: 'Surging Sparks',
        region: 'en',
        ptcgoCode: 'ssp',
      },
      {
        code: 'm2a',
        name: 'Mega Dream ex',
        region: 'jp',
        ptcgoCode: null,
      },
      {
        code: 'sv4a',
        name: 'Shiny Treasure ex',
        region: 'jp',
        ptcgoCode: null,
      },
      {
        code: 'sv8a',
        name: 'Terastal Fest ex',
        region: 'jp',
        ptcgoCode: null,
      },
    ]);
  });

  test('skips card set writes when there are no parsed sets', async ({ database }) => {
    await expect(upsertPokemonCardSets(database, [])).resolves.toBe(0);
    await expect(countPokemonCardSets(database)).resolves.toBe(0);
  });
});
