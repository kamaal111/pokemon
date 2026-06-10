import { describe, expect, test } from 'vitest';

import {
  fetchPokemonTcgApiEnglishCardSets,
  parsePokemonTcgApiEnglishCardSets,
} from './pokemon-tcg-api.ts';
import { POKEMON_TCG_API_CARD_SETS_URL } from './constants.ts';

describe('fetchPokemonTcgApiEnglishCardSets', () => {
  test('fails clearly when the Pokemon TCG set request fails', async () => {
    await expect(
      fetchPokemonTcgApiEnglishCardSets(() =>
        Promise.resolve(new Response('unavailable', { status: 503 })),
      ),
    ).rejects.toThrow(`Failed to fetch ${POKEMON_TCG_API_CARD_SETS_URL}: 503`);
  });
});

describe('parsePokemonTcgApiEnglishCardSets', () => {
  test('extracts English set names and codes from the Pokemon TCG API response', () => {
    const cardSets = parsePokemonTcgApiEnglishCardSets({
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
        {
          id: 'si1',
          name: 'Southern Islands',
          series: 'Other',
          printedTotal: 18,
          total: 18,
        },
      ],
    });

    expect(cardSets).toEqual([
      {
        code: 'si1',
        name: 'Southern Islands',
        region: 'en',
        source: 'pokemon-tcg-api',
        ptcgoCode: null,
      },
      {
        code: 'sv3pt5',
        name: '151',
        region: 'en',
        source: 'pokemon-tcg-api',
        ptcgoCode: 'mew',
      },
      {
        code: 'sv8',
        name: 'Surging Sparks',
        region: 'en',
        source: 'pokemon-tcg-api',
        ptcgoCode: 'ssp',
      },
    ]);
  });
});
