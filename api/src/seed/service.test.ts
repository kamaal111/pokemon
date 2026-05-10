import { describe, expect, vi } from 'vitest';
import { eq } from 'drizzle-orm';

import { integrationTest as test } from '../tests/fixtures.ts';
import { pokemonSpecies } from '../db/schema/index.ts';
import {
  countPokemonSpecies,
  getExistingSpeciesIds,
  getLastSuccessfulSeedSyncAt,
  insertPokemonSpecies,
} from './repository.ts';
import {
  buildSpeciesListingUrl,
  collectPokemonSpeciesSummaries,
  fetchPokemonSpeciesPage,
} from './pokeapi.ts';
import { seedPokedex } from './service.ts';

const TEST_UPSTREAM_SPECIES_COUNT = 45;
const EXTRA_DEPS = {};

function countDetailFetches(apiMock: { requestUrls(): string[] }): number {
  return apiMock
    .requestUrls()
    .filter((requestUrl) =>
      new URL(requestUrl).pathname.match(/^\/api\/v2\/pokemon-species\/\d+\/?$/),
    ).length;
}

describe('seedPokedex', () => {
  test('seeds all reported upstream species and becomes a cooldown no-op on rerun', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    const firstRun = await seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database });

    expect(firstRun).toEqual({ saved: TEST_UPSTREAM_SPECIES_COUNT });
    expect(apiMock.fetch).toHaveBeenCalledTimes(48);
    expect(countDetailFetches(apiMock)).toBe(TEST_UPSTREAM_SPECIES_COUNT);
    await expect(countPokemonSpecies(database)).resolves.toBe(TEST_UPSTREAM_SPECIES_COUNT);
    await expect(getLastSuccessfulSeedSyncAt(database)).resolves.not.toBeNull();

    apiMock.reset();
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);

    const secondRun = await seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database });

    expect(secondRun).toEqual({ saved: 0 });
    expect(apiMock.fetch).toHaveBeenCalledTimes(1);
    await expect(countPokemonSpecies(database)).resolves.toBe(TEST_UPSTREAM_SPECIES_COUNT);
  });

  test('resumes from the contiguous prefix and skips already-seeded noncontiguous ids', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    await database.db.insert(pokemonSpecies).values(
      [...Array.from({ length: 18 }, (_, index) => index + 1), 25].map((id) => ({
        id,
        name: `pokemon-${id}`,
        colorName: `color-${id}`,
        evolvesFromSpeciesName: id === 1 ? null : `pokemon-${id - 1}`,
        generationName: 'generation-i',
        habitatName: null,
        isBaby: false,
        isLegendary: false,
        isMythical: false,
        seededAt: new Date().toISOString(),
      })),
    );

    const result = await seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database });

    expect(result).toEqual({ saved: TEST_UPSTREAM_SPECIES_COUNT - 19 });
    expect(apiMock.fetch).toHaveBeenCalledWith(buildSpeciesListingUrl(20));
    expect(apiMock.fetch).not.toHaveBeenCalledWith('https://pokeapi.co/api/v2/pokemon-species/25/');
    expect(countDetailFetches(apiMock)).toBe(TEST_UPSTREAM_SPECIES_COUNT - 19);
    await expect(countPokemonSpecies(database)).resolves.toBe(TEST_UPSTREAM_SPECIES_COUNT);

    await expect(
      database.db
        .select({ id: pokemonSpecies.id })
        .from(pokemonSpecies)
        .where(eq(pokemonSpecies.id, 25)),
    ).resolves.toEqual([{ id: 25 }]);
  });

  test('fails clearly when the species listing request fails', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.mockUrl(buildSpeciesListingUrl(0), new Response('upstream failed', { status: 500 }));

    await expect(seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database })).rejects.toThrow(
      `Failed to fetch ${buildSpeciesListingUrl(0)}: 500`,
    );
    await expect(countPokemonSpecies(database)).resolves.toBe(0);
  });

  test('returns zero when listed candidates already exist outside the prefix', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    await database.db.insert(pokemonSpecies).values({
      id: 25,
      name: 'pokemon-25',
      colorName: 'color-25',
      evolvesFromSpeciesName: 'pokemon-24',
      generationName: 'generation-i',
      habitatName: null,
      isBaby: false,
      isLegendary: false,
      isMythical: false,
      seededAt: new Date().toISOString(),
    });
    apiMock.mockUrl(
      buildSpeciesListingUrl(0),
      new Response(
        JSON.stringify({
          count: 1,
          next: null,
          previous: null,
          results: [
            {
              name: 'pokemon-25',
              url: 'https://pokeapi.co/api/v2/pokemon-species/25/',
            },
          ],
        }),
      ),
    );

    const result = await seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database });

    expect(result).toEqual({ saved: 0 });
    expect(countDetailFetches(apiMock)).toBe(0);
    await expect(countPokemonSpecies(database)).resolves.toBe(1);
    await expect(getLastSuccessfulSeedSyncAt(database)).resolves.not.toBeNull();
  });

  test('handles empty repository and duplicate insert edge cases', async ({ database }) => {
    await expect(getExistingSpeciesIds(database, [])).resolves.toEqual(new Set());

    const species = {
      id: 1,
      name: 'pokemon-1',
      colorName: 'color-1',
      evolvesFromSpeciesName: null,
      generationName: 'generation-i',
      habitatName: null,
      isBaby: false,
      isLegendary: false,
      isMythical: false,
      names: [],
      genera: [],
      pokedexNumbers: [],
    };

    await expect(insertPokemonSpecies(database, species, new Date().toISOString())).resolves.toBe(
      1,
    );
    await expect(insertPokemonSpecies(database, species, new Date().toISOString())).resolves.toBe(
      0,
    );
  });

  test('allows reseeding after the cooldown expires', async ({ apiMock, database }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    const now = new Date('2026-05-10T08:00:00.000Z');
    const seedDependencies = {
      fetch: apiMock.fetch,
      cooldownDays: 1,
      now: () => now,
    };

    await expect(seedPokedex({ ...seedDependencies, database })).resolves.toEqual({
      saved: TEST_UPSTREAM_SPECIES_COUNT,
    });

    apiMock.reset();
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    const expiredNow = new Date('2026-05-11T08:00:00.001Z');

    await expect(
      seedPokedex({ ...seedDependencies, database, now: () => expiredNow }),
    ).resolves.toEqual({ saved: 0 });
    expect(apiMock.fetch).toHaveBeenCalledTimes(1);
  });

  test('does not start the cooldown after a failed run', async ({ apiMock, database }) => {
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);
    const now = new Date('2026-05-10T08:00:00.000Z');
    const seedDependencies = {
      fetch: apiMock.fetch,
      cooldownDays: 1,
      now: () => now,
    };
    apiMock.mockUrl(
      'https://pokeapi.co/api/v2/pokemon-species/3/',
      new Response('upstream failed', { status: 500 }),
    );

    await expect(seedPokedex({ ...seedDependencies, database })).rejects.toThrow(
      'Failed to fetch https://pokeapi.co/api/v2/pokemon-species/3/: 500',
    );
    await expect(getLastSuccessfulSeedSyncAt(database)).resolves.toBeNull();

    apiMock.reset();
    apiMock.setTotalSpeciesCount(TEST_UPSTREAM_SPECIES_COUNT);

    await expect(seedPokedex({ ...seedDependencies, database })).resolves.toEqual({
      saved: TEST_UPSTREAM_SPECIES_COUNT,
    });
  });

  test('does not mark a successful sync when the upstream listing is still incomplete', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    apiMock.mockUrl(
      buildSpeciesListingUrl(0),
      new Response(
        JSON.stringify({
          count: 3,
          next: null,
          previous: null,
          results: [
            { name: 'pokemon-1', url: 'https://pokeapi.co/api/v2/pokemon-species/1/' },
            { name: 'pokemon-2', url: 'https://pokeapi.co/api/v2/pokemon-species/2/' },
          ],
        }),
      ),
    );

    await expect(seedPokedex({ ...EXTRA_DEPS, ...seedDependencies, database })).resolves.toEqual({
      saved: 2,
    });
    await expect(getLastSuccessfulSeedSyncAt(database)).resolves.toBeNull();
  });
});

describe('collectPokemonSpeciesSummaries', () => {
  test('skips already processed, out-of-range, and duplicate species summaries', async () => {
    const fetchImpl = vi.fn<typeof fetch>(async () => {
      return new Response(
        JSON.stringify({
          count: 22,
          next: null,
          previous: null,
          results: [
            { name: 'pokemon-20', url: 'https://pokeapi.co/api/v2/pokemon-species/20/' },
            { name: 'pokemon-21', url: 'https://pokeapi.co/api/v2/pokemon-species/21/' },
            { name: 'pokemon-21', url: 'https://pokeapi.co/api/v2/pokemon-species/21/' },
            { name: 'pokemon-23', url: 'https://pokeapi.co/api/v2/pokemon-species/23/' },
            { name: 'pokemon-22', url: 'https://pokeapi.co/api/v2/pokemon-species/22/' },
          ],
        }),
      );
    });
    const firstPage = await fetchPokemonSpeciesPage(0, fetchImpl);

    await expect(collectPokemonSpeciesSummaries(20, 22, firstPage, fetchImpl)).resolves.toEqual([
      {
        id: 21,
        name: 'pokemon-21',
        url: 'https://pokeapi.co/api/v2/pokemon-species/21/',
      },
      {
        id: 22,
        name: 'pokemon-22',
        url: 'https://pokeapi.co/api/v2/pokemon-species/22/',
      },
    ]);
    expect(fetchImpl).toHaveBeenCalledWith(buildSpeciesListingUrl(0));
  });

  test('fails when a species id cannot be determined from the upstream URL', async () => {
    const fetchImpl = vi.fn<typeof fetch>(async () => {
      return new Response(
        JSON.stringify({
          count: 1,
          next: null,
          previous: null,
          results: [{ name: 'pokemon-x', url: 'https://pokeapi.co/api/v2/pokemon-species/x/' }],
        }),
      );
    });

    await expect(fetchPokemonSpeciesPage(0, fetchImpl)).rejects.toThrow(
      'Could not determine species id from https://pokeapi.co/api/v2/pokemon-species/x/',
    );
  });
});
