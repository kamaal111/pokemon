import type { Database } from '@/database';
import {
  getContiguousSeededPrefix,
  getExistingSpeciesIds,
  insertPokemonSpecies,
} from './repository';
import { POKEDEX_SEED_TARGET } from './constants';
import { collectPokemonSpeciesSummaries, fetchPokemonSpeciesDetails } from './pokeapi';
import type { SeedPokeDexSuccessResponse } from './responses';

export interface SeedDependencies {
  fetch: typeof fetch;
}

interface SeedPokedexOptions extends SeedDependencies {
  database: Database;
}

export async function seedPokedex(
  options: SeedPokedexOptions,
): Promise<SeedPokeDexSuccessResponse> {
  const contiguousSeededPrefix = await getContiguousSeededPrefix(options.database);
  if (contiguousSeededPrefix >= POKEDEX_SEED_TARGET) {
    return { saved: 0 };
  }

  const candidateSpeciesSummaries = await collectPokemonSpeciesSummaries(
    contiguousSeededPrefix,
    options.fetch,
  );
  const existingSpeciesIds = await getExistingSpeciesIds(
    options.database,
    candidateSpeciesSummaries.map((species) => species.id),
  );
  const missingSpeciesSummaries = candidateSpeciesSummaries.filter(
    (species) => !existingSpeciesIds.has(species.id),
  );
  if (missingSpeciesSummaries.length === 0) {
    return { saved: 0 };
  }

  const seededAt = new Date().toISOString();
  const normalizedPokemonSpecies = await fetchPokemonSpeciesDetails(
    missingSpeciesSummaries,
    options.fetch,
  );

  let saved = 0;
  for (const species of normalizedPokemonSpecies) {
    saved += await insertPokemonSpecies(options.database, species, seededAt);
  }

  return { saved };
}
