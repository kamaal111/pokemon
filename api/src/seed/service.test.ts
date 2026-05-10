import { describe, expect, vi } from 'vitest';
import { eq } from 'drizzle-orm';

import { integrationTest as test } from '@/tests/fixtures';
import { pokemonSpecies } from '@/db/schema';
import { countPokemonSpecies, getExistingSpeciesIds, insertPokemonSpecies } from './repository';
import { buildSpeciesListingUrl, collectPokemonSpeciesSummaries } from './pokeapi';
import { seedPokedex } from './service';

function countDetailFetches(apiMock: { requestUrls(): string[] }): number {
  return apiMock.requestUrls().filter((url) => url.includes('/pokemon-species/')).length;
}

describe('seedPokedex', () => {
  test('seeds the first forty species and becomes a no-op on rerun', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
    const firstRun = await seedPokedex({ ...seedDependencies, database });

    expect(firstRun).toEqual({ saved: 40 });
    expect(apiMock.fetch).toHaveBeenCalledTimes(42);
    expect(countDetailFetches(apiMock)).toBe(40);
    await expect(countPokemonSpecies(database)).resolves.toBe(40);

    apiMock.reset();

    const secondRun = await seedPokedex({ ...seedDependencies, database });

    expect(secondRun).toEqual({ saved: 0 });
    expect(apiMock.fetch).not.toHaveBeenCalled();
    await expect(countPokemonSpecies(database)).resolves.toBe(40);
  });

  test('resumes from the contiguous prefix and skips already-seeded noncontiguous ids', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
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

    const result = await seedPokedex({ ...seedDependencies, database });

    expect(result).toEqual({ saved: 21 });
    expect(apiMock.fetch).toHaveBeenCalledWith(buildSpeciesListingUrl(18));
    expect(apiMock.fetch).not.toHaveBeenCalledWith('https://pokeapi.co/api/v2/pokemon-species/25/');
    expect(countDetailFetches(apiMock)).toBe(21);
    await expect(countPokemonSpecies(database)).resolves.toBe(40);

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

    await expect(seedPokedex({ ...seedDependencies, database })).rejects.toThrow(
      `Failed to fetch ${buildSpeciesListingUrl(0)}: 500`,
    );
    await expect(countPokemonSpecies(database)).resolves.toBe(0);
  });

  test('returns zero when listed candidates already exist outside the prefix', async ({
    apiMock,
    database,
    seedDependencies,
  }) => {
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

    const result = await seedPokedex({ ...seedDependencies, database });

    expect(result).toEqual({ saved: 0 });
    expect(countDetailFetches(apiMock)).toBe(0);
    await expect(countPokemonSpecies(database)).resolves.toBe(1);
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
});

describe('collectPokemonSpeciesSummaries', () => {
  test('skips already processed, out-of-range, and duplicate species summaries', async () => {
    const fetchImpl = vi.fn<typeof fetch>(async () => {
      return new Response(
        JSON.stringify({
          count: 5,
          next: null,
          previous: null,
          results: [
            { name: 'pokemon-20', url: 'https://pokeapi.co/api/v2/pokemon-species/20/' },
            { name: 'pokemon-21', url: 'https://pokeapi.co/api/v2/pokemon-species/21/' },
            { name: 'pokemon-21', url: 'https://pokeapi.co/api/v2/pokemon-species/21/' },
            { name: 'pokemon-41', url: 'https://pokeapi.co/api/v2/pokemon-species/41/' },
            { name: 'pokemon-22', url: 'https://pokeapi.co/api/v2/pokemon-species/22/' },
          ],
        }),
      );
    });

    await expect(collectPokemonSpeciesSummaries(20, fetchImpl)).resolves.toEqual([
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
    expect(fetchImpl).toHaveBeenCalledWith(buildSpeciesListingUrl(20));
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

    await expect(collectPokemonSpeciesSummaries(0, fetchImpl)).rejects.toThrow(
      'Could not determine species id from https://pokeapi.co/api/v2/pokemon-species/x/',
    );
  });
});
