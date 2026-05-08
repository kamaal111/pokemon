import { describe, expect } from 'vitest';
import { eq } from 'drizzle-orm';

import { integrationTest as test } from '@/tests/fixtures';
import { pokemonSpecies } from '@/db/schema';
import { countPokemonSpecies } from './repository';
import { buildSpeciesListingUrl } from './pokeapi';
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
});
